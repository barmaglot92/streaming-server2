# # ARG S3FS_VERSION=v1.91
# ARG FFMPEG_VERSION=5.1.2

# # Build the FFmpeg-build image.
# FROM alpine:3.17 as build-ffmpeg
# ARG FFMPEG_VERSION
# ARG PREFIX=/usr/local/ffmpeg_build
# ARG MAKEFLAGS="-j4"

# # FFmpeg build dependencies.
# RUN apk add --update --no-cache \
#   build-base \
#   coreutils \
#   freetype-dev \
#   lame-dev \
#   libogg-dev \
#   libass \
#   libass-dev \
#   libvpx-dev \
#   libvorbis-dev \
#   libwebp-dev \
#   libtheora-dev \
#   opus-dev \
#   pkgconf \
#   pkgconfig \
#   rtmpdump-dev \
#   wget \
#   x264-dev \
#   x265-dev \
#   yasm


# # Get FFmpeg source.
# RUN cd /tmp/ && \
#   wget http://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.gz && \
#   tar zxf ffmpeg-${FFMPEG_VERSION}.tar.gz && rm ffmpeg-${FFMPEG_VERSION}.tar.gz

# # Compile ffmpeg.
# RUN cd /tmp/ffmpeg-${FFMPEG_VERSION} && \
#   ./configure \
#   # --pkg-config-flags="--static" \
#   --prefix=${PREFIX} \
#   --enable-libx264 \
#   --enable-gpl \
#   --enable-version3 \
#   --enable-nonfree  \
#   --enable-librtmp \
#   --enable-libfreetype \
#   --disable-debug \
#   --disable-ffplay \
#   --disable-doc \
#   --enable-small \
#   --extra-libs="-lpthread -lm" && \
#   make && make install && make distclean

# # Cleanup.
# RUN rm -rf /var/cache/* /tmp/*

# #############################
# #Build the NGINX-build image.
# FROM alpine:3.17 as build-nginx
# ARG NGINX_VERSION
# ARG NGINX_RTMP_VERSION

# # Build dependencies.
# RUN apk add --update --no-cache \
#   build-base \
# #   ca-certificates \
# #   curl \
#   gcc \
#   libc-dev \
#   libgcc \
#   linux-headers \
#   make \
# #   musl-dev \
#   openssl \
#   openssl-dev \
#   pcre \
#   pcre-dev \
#   pkgconf \
#   pkgconfig \
#   zlib-dev

# # Get nginx source.
# RUN cd /tmp && \
#   wget https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz && \
#   tar zxf nginx-${NGINX_VERSION}.tar.gz && \
#   rm nginx-${NGINX_VERSION}.tar.gz

# # Get nginx-rtmp module.
# RUN cd /tmp && \
#   wget https://github.com/arut/nginx-rtmp-module/archive/refs/tags/v${NGINX_RTMP_VERSION}.tar.gz -O nginx-rtmp-module-${NGINX_RTMP_VERSION}.tar.gz && \
#   tar zxf nginx-rtmp-module-${NGINX_RTMP_VERSION}.tar.gz && rm nginx-rtmp-module-${NGINX_RTMP_VERSION}.tar.gz

# # Compile nginx with nginx-rtmp module.
# RUN cd /tmp/nginx-${NGINX_VERSION} && \
#   ./configure \
#   --prefix=/usr/local/nginx_build \
#   --conf-path=/etc/nginx/nginx.conf \
#   --add-module=/tmp/nginx-rtmp-module-${NGINX_RTMP_VERSION} \
#   --conf-path=/etc/nginx/nginx.conf \
#   --with-threads \
#   --with-file-aio && \
#   make && make install

# # ###############################


# # Build the s3fs image.
# FROM alpine:3.17 as build-s3fs
# ARG S3FS_VERSION
# RUN apk --update --no-cache add --virtual build-dependencies \
#         build-base alpine-sdk \
#         fuse fuse-dev \
#         automake autoconf git \
#         curl-dev libxml2-dev  \
#         ca-certificates pcre;
        

# RUN git clone https://github.com/s3fs-fuse/s3fs-fuse.git; \
#    cd s3fs-fuse; \
#    git checkout tags/${S3FS_VERSION}; \
#    ./autogen.sh; \
#    ./configure --prefix=/usr/local/s3fs_build; \
#    make; \
#    make install; \
#    rm -rf /var/cache/apk/*;

# ##########################
# # Build the release image.
# FROM alpine:3.17
# LABEL MAINTAINER Andrey Zhvakin <barmaglot92@gmail.com>

# RUN apk --no-cache --update add \
#   bash \
#   pcre \
#   x264-dev \
#   rtmpdump \
#   freetype \
#   fuse \
#   fuse-dev \
#   libxml2-dev \
#   alpine-sdk


# COPY --from=build-nginx /usr/local/nginx_build /usr/local/nginx_build
# COPY --from=build-s3fs /usr/local/s3fs_build /usr/local/s3fs_build
# COPY --from=build-ffmpeg /usr/local/ffmpeg_build /usr/local/ffmpeg_build

# # Add NGINX path, config and static files.
# ENV PATH "${PATH}:/usr/local/nginx_build/sbin:/usr/local/s3fs_build/bin:/usr/local/ffmpeg_build/bin"
# ADD nginx.conf /etc/nginx/nginx.conf
# ADD fuse.conf /etc/fuse.conf
# RUN mkdir -p /opt/data/hls


# ADD entrypoint.sh /
# RUN chmod +x /entrypoint.sh

# EXPOSE 1935

# CMD ["/entrypoint.sh"]


FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Moscow

RUN apt-get update
RUN apt-get -yq install \
  build-essential \
  libpcre3-dev \
  zlib1g-dev \
  tclsh \
  cmake \
  libssl-dev \
  php-fpm \
  php-curl \
  git

RUN cd /opt && \
    git clone https://github.com/nginx/nginx/ && \
    git clone https://github.com/kaltura/media-framework/ && \
    git clone https://github.com/Haivision/srt && \
    git clone https://github.com/kaltura/nginx-srt-module && \
    git clone https://github.com/kaltura/nginx-stream-preread-str-module


RUN cd /opt/srt && \
    ./configure && \
    make && \
    make install

RUN cd /opt/nginx && \
    /opt/media-framework/conf/build.sh /opt/nginx-srt-module /opt/nginx-stream-preread-str-module && \
    make && \
    make install

RUN mv /usr/local/nginx/conf/nginx.conf /usr/local/nginx/conf/nginx.conf.orig && \
  ln -s /opt/media-framework/conf/nginx.conf /usr/local/nginx/conf/nginx.conf && \
  mkdir /var/log/nginx

CMD ["/usr/local/nginx/sbin/nginx"]
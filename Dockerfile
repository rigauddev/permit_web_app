FROM ghcr.io/cirruslabs/flutter:3.41.9 AS build

WORKDIR /app

COPY pubspec.* ./
RUN flutter pub get

COPY . .

ARG API_BASE_URL=http://localhost:8000
ARG APP_APK_DOWNLOAD_URL=
RUN flutter build web \
    --dart-define=API_BASE_URL=${API_BASE_URL} \
    --dart-define=APP_APK_DOWNLOAD_URL=${APP_APK_DOWNLOAD_URL}

FROM nginx:1.27-alpine

RUN rm /etc/nginx/conf.d/default.conf

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]

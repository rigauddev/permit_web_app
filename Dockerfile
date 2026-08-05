# Etapa 1 - Build do Flutter Web
FROM cirrusci/flutter:latest AS build

WORKDIR /app

# Copiar o pubspec antes para aproveitar cache
COPY pubspec.* ./
RUN flutter pub get

# Copiar o resto do projeto
COPY . .

# Gerar build para web
RUN flutter build web

# Etapa 2 - Servir com NGINX
FROM nginx:alpine

# Remover config default do NGINX
RUN rm /etc/nginx/conf.d/default.conf

# Copiar nossa configuração customizada
COPY nginx.conf /etc/nginx/conf.d

# Copiar o build do Flutter Web para a pasta pública do NGINX
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]

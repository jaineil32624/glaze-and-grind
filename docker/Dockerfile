# Glaze & Grind — browser build served by nginx.
#   docker run --rm -p 8080:80 ghcr.io/jaineil32624/glaze-and-grind:latest
# then open http://localhost:8080
FROM nginx:1.27-alpine
LABEL org.opencontainers.image.title="Glaze & Grind" \
      org.opencontainers.image.description="Donut & coffee shop tycoon (Godot 4) — playable in your browser" \
      org.opencontainers.image.source="https://github.com/jaineil32624/glaze-and-grind" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.authors="Jaineil Rana"
COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
COPY web/ /usr/share/nginx/html/
EXPOSE 80

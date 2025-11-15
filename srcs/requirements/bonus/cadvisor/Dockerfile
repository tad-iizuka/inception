# Penultimate stable version of Debian
FROM debian:bookworm

# Install packages
RUN apt update -y && apt install wget -y 
RUN wget https://github.com/google/cadvisor/releases/download/v0.52.1/cadvisor-v0.52.1-linux-arm64

RUN chmod +x cadvisor-v0.52.1-linux-arm64

CMD ["./cadvisor-v0.52.1-linux-arm64"]

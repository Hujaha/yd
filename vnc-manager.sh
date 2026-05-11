#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
NC='\033[0m'

VNC_PORT=5901
NOVNC_PORT=8080
VNC_GEOMETRY="1024x768"
SSH_TUNNEL="-p 443 -R 0:127.0.0.1:${NOVNC_PORT} qr@free.pinggy.io"

show_menu() {
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}      VNC + SSH Tunnel Manager${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    echo -e "${GREEN}  [1] Установить и запустить VNC${NC}"
    echo -e "${RED}  [2] Удалить / остановить VNC${NC}"
    echo -e "${YELLOW}  [3] Выход${NC}"
    echo ""
}

check_deps() {
    for cmd in vncserver websockify ssh; do
        if ! command -v "$cmd" &> /dev/null; then
            echo -e "${RED}[!] $cmd не найден!${NC}"
            echo -e "${YELLOW}    Установите: sudo apt install tigervnc-standalone-server websockify openssh-client${NC}"
            read -r -p "Нажмите Enter..."
            return 1
        fi
    done
    return 0
}

install_vnc() {
    echo -e "${CYAN}--- Установка и запуск VNC ---${NC}"
    
    if ! check_deps; then return; fi
    
    echo -e "${YELLOW}[*] Очистка старых процессов...${NC}"
    pkill -f "vncserver" 2>/dev/null
    pkill -f "websockify" 2>/dev/null
    pkill -f "ssh.*qr@free.pinggy.io" 2>/dev/null
    sleep 1
    
    if [ ! -f "$HOME/.vnc/passwd" ]; then
        echo -e "${YELLOW}[!] Установите пароль для VNC:${NC}"
        vncpasswd
        if [ $? -ne 0 ]; then
            echo -e "${RED}[!] Пароль не установлен. Отмена.${NC}"
            read -r -p "Нажмите Enter..."
            return
        fi
    fi
    
    echo -e "${YELLOW}[*] Запуск VNC сервера...${NC}"
    vncserver :1 -geometry ${VNC_GEOMETRY} -depth 24 -localhost yes
    if [ $? -ne 0 ]; then
        echo -e "${RED}[!] Ошибка запуска VNC${NC}"
        read -r -p "Нажмите Enter..."
        return
    fi
    echo -e "${GREEN}[+] VNC: localhost:${VNC_PORT}${NC}"
    
    echo -e "${YELLOW}[*] Запуск noVNC...${NC}"
    NOVNC_WEB="/usr/share/novnc"
    [ ! -d "$NOVNC_WEB" ] && NOVNC_WEB="/usr/share/novnc/www"
    
    if [ ! -d "$NOVNC_WEB" ]; then
        echo -e "${YELLOW}[*] Скачивание noVNC...${NC}"
        TMP="$HOME/.novnc-tmp"
        mkdir -p "$TMP" && cd "$TMP"
        git clone --depth 1 https://github.com/novnc/noVNC.git 2>/dev/null || \
            (wget -q https://github.com/novnc/noVNC/archive/refs/heads/master.zip && unzip -q master.zip && mv noVNC-master noVNC)
        NOVNC_WEB="$TMP/noVNC"
        cd - > /dev/null
    fi
    
    websockify -D --web="$NOVNC_WEB" ${NOVNC_PORT} localhost:${VNC_PORT} 2>/dev/null
    sleep 1
    echo -e "${GREEN}[+] noVNC: http://localhost:${NOVNC_PORT}${NC}"
    
    echo -e "${YELLOW}[*] Создание SSH туннеля Pinggy...${NC}"
    echo -e "${CYAN}    Ожидание URL...${NC}"
    
    TEMP_LOG=$(mktemp)
    ssh ${SSH_TUNNEL} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR 2> >(tee "$TEMP_LOG" >&2) &
    SSH_PID=$!
    
    URL=""
    for i in {1..25}; do
        URL=$(grep -oE 'https?://[a-zA-Z0-9._-]+\.pinggy\.[a-z]+' "$TEMP_LOG" | head -1)
        [ -n "$URL" ] && break
        sleep 1
    done
    
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}     ✅ VNC + ТУННЕЛЬ ЗАПУЩЕНЫ!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    if [ -n "$URL" ]; then
        echo -e "${CYAN}🌐 Публичная ссылка:${NC}"
        echo -e "${GREEN}   ${URL}${NC}"
        echo ""
        echo -e "${YELLOW}   Откройте в браузере для доступа к рабочему столу${NC}"
    else
        echo -e "${YELLOW}⚠️  URL не определён автоматически.${NC}"
        echo -e "${CYAN}   Ищите ссылку вида https://xxx.pinggy.link в выводе выше${NC}"
    fi
    echo ""
    echo -e "${BLUE}--- Локально ---${NC}"
    echo -e "   VNC:   localhost:${VNC_PORT}"
    echo -e "   noVNC: http://localhost:${NOVNC_PORT}"
    echo ""
    echo -e "${RED}--- Для остановки выберите [2] в меню ---${NC}"
    
    rm -f "$TEMP_LOG"
    
    echo ""
    read -r -p "Нажмите Enter для возврата в меню (процессы останутся активными)..."
}

remove_vnc() {
    echo -e "${RED}--- Остановка и удаление VNC ---${NC}"
    
    echo -e "${YELLOW}[*] Остановка SSH туннеля...${NC}"
    pkill -f "ssh.*qr@free.pinggy.io" 2>/dev/null
    
    echo -e "${YELLOW}[*] Остановка websockify...${NC}"
    pkill -f "websockify" 2>/dev/null
    
    echo -e "${YELLOW}[*] Остановка VNC сервера...${NC}"
    vncserver -kill :1 2>/dev/null
    vncserver -kill :2 2>/dev/null
    
    rm -rf "$HOME/.novnc-tmp" 2>/dev/null
    
    echo ""
    echo -e "${GREEN}[+] Все сервисы остановлены и удалены.${NC}"
    read -r -p "Нажмите Enter..."
}

while true; do
    show_menu
    echo -n "Выберите действие: "
    read -r choice
    echo ""
    
    case "$choice" in
        1)
            install_vnc
            ;;
        2)
            remove_vnc
            ;;
        3)
            echo -e "${CYAN}Выход.${NC}"
            exit 0
            ;;
        "")
            echo -e "${RED}Пустой ввод! Введите 1, 2 или 3.${NC}"
            sleep 1
            ;;
        *)
            echo -e "${RED}Неверный выбор: '$choice'${NC}"
            sleep 1
            ;;
    esac
done

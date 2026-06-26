// ========================================
// ОБЩИЕ ФУНКЦИИ ДЛЯ ВСЕГО ПРОЕКТА
// ========================================

// ===== Базовый путь к статике =====
const STATIC_PATH = '/static/';

// ===== Clippy GIFs =====
const GIFS = {
    hello: STATIC_PATH + 'clippy/hello.gif',
    typing: STATIC_PATH + 'clippy/typing.gif',
    error: STATIC_PATH + 'clippy/error.gif',
    success: STATIC_PATH + 'clippy/success.gif',
    pointing: STATIC_PATH + 'clippy/pointing.gif'
};

// ===== Проверка загрузки GIF =====
function isGifLoaded(url) {
    return new Promise((resolve) => {
        const img = new Image();
        img.onload = () => resolve(true);
        img.onerror = () => resolve(false);
        img.src = url;
        setTimeout(() => resolve(false), 2000);
    });
}

// ===== Установка Clippy =====
async function setClippy(element, gifKey, options = {}) {
    const {
        isError = false,
        isSuccess = false,
        isPointing = false,
        isTyping = false
    } = options;

    const fallbackElement = document.getElementById(element.id + 'Fallback');
    const url = GIFS[gifKey] || GIFS.hello;
    
    const loaded = await isGifLoaded(url);
    
    if (!loaded) {
        element.classList.add('fallback');
        if (fallbackElement) {
            fallbackElement.classList.add('show');
            if (isError) {
                fallbackElement.style.animation = 'clippyShake 0.5s ease forwards, clippyFloat 2s ease-in-out infinite';
            } else if (isSuccess) {
                fallbackElement.style.animation = 'clippySuccess 0.6s ease forwards, clippyFloat 2s ease-in-out infinite';
            } else if (isPointing) {
                fallbackElement.style.animation = 'clippyPoint 0.8s ease forwards, clippyFloat 2s ease-in-out infinite';
            } else {
                fallbackElement.style.animation = 'clippyFloat 2s ease-in-out infinite';
            }
        }
        return;
    }
    
    element.classList.remove('fallback');
    if (fallbackElement) {
        fallbackElement.classList.remove('show');
    }
    element.src = url;
    
    if (isError) {
        element.className = 'clippy-gif error';
    } else if (isSuccess) {
        element.className = 'clippy-gif success';
    } else if (isPointing) {
        element.className = 'clippy-gif pointing';
    } else if (isTyping || gifKey === 'typing') {
        element.className = 'clippy-gif typing';
    } else {
        element.className = 'clippy-gif';
    }
}

// ===== Обновление речи Clippy =====
function updateClippySpeech(speechElement, text, animate = false) {
    if (!speechElement) return;
    speechElement.innerHTML = text;
    if (animate) {
        speechElement.style.animation = 'none';
        setTimeout(() => {
            speechElement.style.animation = 'errorSlide 0.3s ease';
        }, 10);
    }
}

// ===== Показать сообщение =====
function showMessage(messageType, message, options = {}) {
    const {
        duration = 5000,
        autoHide = true,
        callback = null
    } = options;

    const msgElement = document.getElementById(messageType + 'Message');
    const textElement = document.getElementById(messageType + 'Text');
    
    if (!msgElement || !textElement) return;
    
    textElement.textContent = message;
    msgElement.classList.add('show');
    
    if (autoHide) {
        setTimeout(() => {
            msgElement.classList.remove('show');
            if (callback) callback();
        }, duration);
    }
}

// ===== Скрыть все сообщения =====
function hideAllMessages() {
    document.querySelectorAll('.message').forEach(msg => {
        msg.classList.remove('show');
    });
}

// ===== Валидация email =====
function validateEmail(email) {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

// ===== Проверка сложности пароля =====
function checkPasswordStrength(password) {
    let score = 0;
    let feedback = '';

    if (password.length >= 8) score += 1;
    if (password.match(/[a-z]/)) score += 1;
    if (password.match(/[A-Z]/)) score += 1;
    if (password.match(/[0-9]/)) score += 1;
    if (password.match(/[^a-zA-Z0-9]/)) score += 1;

    if (password.length === 0) {
        return { score: 0, feedback: 'Сложность', color: 'rgba(255,255,255,0.4)' };
    }

    if (score <= 2) {
        feedback = 'Слабый';
        color = '#ef4444';
    } else if (score <= 3) {
        feedback = 'Средний';
        color = '#f59e0b';
    } else {
        feedback = 'Сильный';
        color = '#34d399';
    }

    return { score: Math.min(score, 5), feedback, color };
}

// ===== Обновление индикатора сложности пароля =====
function updatePasswordStrength(passwordInput, strengthFill, strengthText) {
    const pwd = passwordInput.value;
    const result = checkPasswordStrength(pwd);
    const percent = (result.score / 5) * 100;
    
    strengthFill.style.width = percent + '%';
    strengthFill.style.background = result.color;
    strengthText.textContent = result.feedback;
    strengthText.className = 'strength-text ' + (result.feedback === 'Сложность' ? '' : 
        result.feedback === 'Слабый' ? 'weak' : 
        result.feedback === 'Средний' ? 'medium' : 'strong');
    
    if (pwd.length > 0 && result.score <= 2) {
        passwordInput.classList.add('error');
        passwordInput.classList.remove('success');
    } else if (pwd.length > 0) {
        passwordInput.classList.remove('error');
        passwordInput.classList.add('success');
    } else {
        passwordInput.classList.remove('error', 'success');
    }
}

// ===== Проверка совпадения паролей =====
function checkPasswordMatch(passwordInput, repeatInput, matchIcon, matchText) {
    const pwd = passwordInput.value;
    const repeat = repeatInput.value;
    
    if (repeat.length === 0) {
        matchIcon.textContent = '⚪';
        matchText.textContent = 'Повторите пароль';
        repeatInput.classList.remove('error', 'success');
        return false;
    }
    
    if (pwd === repeat) {
        matchIcon.textContent = '✅';
        matchText.textContent = 'Пароли совпадают';
        repeatInput.classList.remove('error');
        repeatInput.classList.add('success');
        return true;
    } else {
        matchIcon.textContent = '❌';
        matchText.textContent = 'Пароли не совпадают';
        repeatInput.classList.remove('success');
        repeatInput.classList.add('error');
        return false;
    }
}

// ===== Автоматическая очистка полей от не-цифр =====
function sanitizeNumericInput(input) {
    input.value = input.value.replace(/\D/g, '');
    if (input.value.length > 6) {
        input.value = input.value.slice(0, 6);
    }
}

// ===== Инициализация radio-кнопок =====
function initRadioButtons() {
    document.querySelectorAll('.radio-group').forEach(group => {
        const options = group.querySelectorAll('.radio-option');
        options.forEach(option => {
            option.addEventListener('click', function() {
                options.forEach(opt => opt.classList.remove('active'));
                this.classList.add('active');
                const radio = this.querySelector('input[type="radio"]');
                if (radio) radio.checked = true;
            });
        });
    });
}

// ===== Таймер для повторной отправки =====
function createTimer(button, timerElement, seconds = 60) {
    let countdown = seconds;
    let interval = null;

    function start() {
        countdown = seconds;
        button.disabled = true;
        timerElement.textContent = `(${countdown}с)`;
        
        clearInterval(interval);
        interval = setInterval(() => {
            countdown--;
            if (countdown <= 0) {
                clearInterval(interval);
                timerElement.textContent = '';
                button.disabled = false;
            } else {
                timerElement.textContent = `(${countdown}с)`;
            }
        }, 1000);
    }

    function reset() {
        clearInterval(interval);
        countdown = 0;
        timerElement.textContent = '';
        button.disabled = false;
    }

    return { start, reset };
}

// ===== Обработка параметров URL =====
function getUrlParam(param) {
    const urlParams = new URLSearchParams(window.location.search);
    return urlParams.get(param);
}

// ===== Загрузка страницы =====
document.addEventListener('DOMContentLoaded', function() {
    // Инициализация radio-кнопок
    initRadioButtons();
    
    // Инициализация Clippy
    const clippyGif = document.getElementById('clippyGif');
    if (clippyGif) {
        setClippy(clippyGif, 'hello');
    }
    
    // Автоматическая очистка кодов
    document.querySelectorAll('.code-input').forEach(input => {
        input.addEventListener('input', function() {
            sanitizeNumericInput(this);
        });
    });
});

// ===== КОПИРОВАНИЕ ТЕКСТА =====
async function copyToClipboard(text, buttonElement = null, duration = 2000) {
    try {
        await navigator.clipboard.writeText(text);
        if (buttonElement) {
            const originalText = buttonElement.textContent;
            buttonElement.textContent = '✅';
            buttonElement.classList.add('copied');
            setTimeout(() => {
                buttonElement.textContent = originalText;
                buttonElement.classList.remove('copied');
            }, duration);
        }
        return true;
    } catch {
        try {
            const textArea = document.createElement('textarea');
            textArea.value = text;
            textArea.style.position = 'fixed';
            textArea.style.opacity = '0';
            document.body.appendChild(textArea);
            textArea.select();
            document.execCommand('copy');
            document.body.removeChild(textArea);
            if (buttonElement) {
                const originalText = buttonElement.textContent;
                buttonElement.textContent = '✅';
                buttonElement.classList.add('copied');
                setTimeout(() => {
                    buttonElement.textContent = originalText;
                    buttonElement.classList.remove('copied');
                }, duration);
            }
            return true;
        } catch {
            return false;
        }
    }
}

function copyElementText(elementId, duration = 2000) {
    const element = document.getElementById(elementId);
    if (!element) return;
    const text = element.textContent.trim();
    const cell = element.closest('.key-cell');
    const button = cell ? cell.querySelector('.btn-copy') : null;
    copyToClipboard(text, button, duration);
}

// ===== ПОКАЗ ПОПАПА =====
function showPopup(type, title, message) {
    // Удаляем старый попап, если есть
    const oldPopup = document.querySelector('.popup-overlay');
    if (oldPopup) oldPopup.remove();

    const overlay = document.createElement('div');
    overlay.className = 'popup-overlay show';
    
    const icon = type === 'success' ? '🎉' : '😔';
    const btnText = type === 'success' ? 'Отлично!' : 'Понял';
    
    overlay.innerHTML = `
        <div class="popup ${type}">
            <span class="popup-icon">${icon}</span>
            <div class="popup-title">${title}</div>
            <div class="popup-message">${message}</div>
            <button class="popup-btn" onclick="this.closest('.popup-overlay').remove()">${btnText}</button>
        </div>
    `;
    
    document.body.appendChild(overlay);
    
    // Закрытие по клику вне попапа
    overlay.addEventListener('click', function(e) {
        if (e.target === this) this.remove();
    });
}

// ========================================
// ЭКСПОРТ ДЛЯ ИСПОЛЬЗОВАНИЯ В ДРУГИХ ФАЙЛАХ
// ========================================
window.showPopup = showPopup;
window.copyToClipboard = copyToClipboard;
window.copyElementText = copyElementText;
window.setClippy = setClippy;
window.updateClippySpeech = updateClippySpeech;
window.showMessage = showMessage;
window.hideAllMessages = hideAllMessages;
window.validateEmail = validateEmail;
window.checkPasswordStrength = checkPasswordStrength;
window.updatePasswordStrength = updatePasswordStrength;
window.checkPasswordMatch = checkPasswordMatch;
window.sanitizeNumericInput = sanitizeNumericInput;
window.initRadioButtons = initRadioButtons;
window.createTimer = createTimer;
window.getUrlParam = getUrlParam;
window.GIFS = GIFS;


// ===== ПОКАЗ ПОПАПА =====
function showPopup(type, title, message) {
    // Удаляем старый попап, если есть
    const oldPopup = document.querySelector('.popup-overlay');
    if (oldPopup) oldPopup.remove();

    const overlay = document.createElement('div');
    overlay.className = 'popup-overlay show';
    
    const icon = type === 'success' ? '🎉' : '😔';
    const btnText = type === 'success' ? 'Отлично!' : 'Понял';
    
    overlay.innerHTML = `
        <div class="popup ${type}">
            <span class="popup-icon">${icon}</span>
            <div class="popup-title">${title}</div>
            <div class="popup-message">${message}</div>
            <button class="popup-btn" onclick="this.closest('.popup-overlay').remove()">${btnText}</button>
        </div>
    `;
    
    document.body.appendChild(overlay);
    
    // Закрытие по клику вне попапа
    overlay.addEventListener('click', function(e) {
        if (e.target === this) this.remove();
    });
}

// Экспортируем
window.showPopup = showPopup;
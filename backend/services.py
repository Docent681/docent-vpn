import json
from random import randint
import requests
from flask import current_app
from config import Config
import os
from sendgrid import SendGridAPIClient
from sendgrid.helpers.mail import Mail

# Функция отправки писем через sendgrid
def seng_sendgrid(code=""):
    message = Mail(
        from_email= str(Config.email)
        to_emails=str(Config.email),
        subject='Подтверждение регистрации в Docent-VPN',
        html_content=f"<strong>Вам был отправлен код подтверждения регистрации {code}. Если вы не регистрировались в Docent-VPN, проигнорируйте это письмо</strong>")
    try:
        sg = SendGridAPIClient(Config.SENDGRID_API)
        sg.set_sendgrid_data_residency("eu")
        # uncomment the above line if you are sending mail using a regional EU subuser
        response = sg.send(message)
    except Exception as e:
        print(e.message)



# Функция, использующаяся при двухэтапной аутентификации для формирования кода
def code_generate():
    res = ""
    for i in range(0, 6):
       res += str(randint(0, 9))
    return res

#функция-обертка для создания нового ключа outline
def create_key(name=None, method=None, password=None, port=None, limit_bytes=None ):
    error = 0
    url_base = f"{Config.API_URL}"
    token = f"{Config.OUTLINE_SECRET_PATH}"
    url = f"{url_base}/{token}/access-keys"

    headers = {
        'Content-Type': 'application/json'
    }

    payload = {}
    if name:
        payload['name'] = name
    if method:
        payload['method'] = method
    if password:
        payload['password'] = password
    if port:
        payload['port'] = port
    if limit_bytes is not None:
        payload['limit'] = {'bytes': limit_bytes}

    try:
        resp = requests.post(url, json=payload, headers=headers, timeout=10, verify=False)
        resp.raise_for_status()
        res = resp.json()
        return res

    except requests.RequestException as e:
        error = 1

    return error

#функция-обертка для удаления ключа по id
def delete_user_key(id):
    error = 0
    url_base = f"{Config.API_URL}"
    token = f"{Config.OUTLINE_SECRET_PATH}"
    url = f"{url_base}/{token}/access-keys/{str(id)}"

    headers = {
        'Content-Type': 'application/json'
    }

    try:
        resp = requests.delete(url, timeout=10, headers=headers, verify=False)
        resp.raise_for_status()

    except requests.RequestException as e:
        error = 1

    return error

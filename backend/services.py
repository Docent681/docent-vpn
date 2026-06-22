import random

def code_generate():
    res = ""
    for i in range(0, 6):
       res += str(random.randint(0, 9))
    return res

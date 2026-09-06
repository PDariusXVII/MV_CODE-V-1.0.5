SE QUISER SOMENTE O LINK DO APK:
https://www.mediafire.com/file/vgtvjasn7fo7vcp/Mv+Code.zip/file

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# 🛠️ Manual de Fabricação, Compilação e Execução — MV Code

> ⚠️ **AVISO IMPORTANTE:** Este é um **projeto em estágio inicial de desenvolvimento**. O recurso de **terminal integrado ainda NÃO está funcionando** nesta versão.

---

## 📱 1. Formas de Instalação e Teste

Você pode rodar ou testar o projeto de duas formas:
1. **Compilação direta via Código-Fonte (Flutter):** Para quem vai desenvolver, alterar código ou depurar no celular.
2. **Instalação via APK:** Também será disponibilizado o arquivo `.apk` pré-compilado para instalação direta no celular Android (sem precisar do Flutter instalado no computador).

---

## 🔧 2. Preparação do Celular Android (Modo Desenvolvedor)

Para compilar e testar diretamente no celular via cabo USB:

1. **Ativar as Opções do Desenvolvedor:**
   - Abra o celular e vá em `Configurações` > `Sobre o Telefone`.
   - Localize o **Número da Versão** (ou *Build Number*) e toque nele **7 vezes seguidas**.
   - O sistema mostrará a mensagem *"Você agora é um desenvolvedor!"*.

2. **Ativar a Depuração por USB:**
   - Volte ao menu de `Configurações` > `Sistema` > `Opções do Desenvolvedor`.
   - Procure a opção **Depuração por USB** (USB Debugging) e **ative a chave**.

3. **Conectar ao Computador:**
   - Conecte o celular ao computador usando um cabo USB de dados.
   - Ao aparecer a mensagem na tela do celular perguntando se autoriza a depuração USB, selecione **Permitir**.

---

## 🚀 3. ⚙️ Configuração Inicial e Execução Automatizada
Para configurar e rodar o projeto rapidamente no Android, siga as instruções abaixo:

1. Extração e Execução
Extraia o arquivo ZIP recebido.
Entre diretamente na pasta extraída (não é necessário navegar por subpastas).
Abra o PowerShell na raiz da pasta e execute os comandos de configuração:
Set-ExecutionPolicy -Scope Process Bypass
.\setup_windows.ps1

2. Limpeza e Execução do Flutter
Assim que o script de configuração terminar, limpa o cache, restaure as dependências e inicie o projeto executando:

flutter clean
flutter pub get
flutter run


---

## 💡 4. Créditos e Inspiração

Este projeto foi inspirado nos seguintes repositórios open-source:
- **Monaco Editor:** https://github.com/Visual-Code-Space/monaco-editor
- **Visual Code Space:** https://github.com/Visual-Code-Space/Visual-Code-Space
- **Cosmic IDE:** https://github.com/aload0/Cosmic-IDE

---

## 🔮 5. Possíveis Adições Futuras

Repositórios sob análise para futuras integrações e expansão do projeto:
- **Termux App (Suporte a terminal/shell):** https://github.com/Visual-Code-Space/termux-app
- **Xed Editor (Referência de editor leve):** https://github.com/Xed-Editor/Xed-Editor

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
![image alt](https://github.com/PDariusXVII/MV_CODE-V-1.0.5/blob/main/Demon/linha%20de%20codigo.jpeg?raw=true)

![image alt](https://github.com/PDariusXVII/MV_CODE-V-1.0.5/blob/main/Demon/rodando%20html.jpeg?raw=true)

![image alt](https://github.com/PDariusXVII/MV_CODE-V-1.0.5/blob/main/Demon/subdivisao%20de%20pastas%28diretorio%29.jpeg?raw=true)

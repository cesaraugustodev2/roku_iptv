# Roku IPTV Player 📺

Um reprodutor de IPTV leve e de alto desempenho para dispositivos Roku, desenvolvido para oferecer uma experiência fluida de streaming de TV ao vivo, filmes e séries. Este aplicativo suporta tanto listas **M3U** quanto a **API Xtream Codes**.


## ✨ Principais Funcionalidades

* **Acesso Unificado**:
    * **TV ao Vivo**: Categorização completa com busca em tempo real e suporte a EPG (Guia de Programação).
    * **Filmes (VOD)**: Suporte a vídeo sob demanda com detecção automática de formato.
    * **Séries**: Organização por temporadas e episódios.
* **Interface Premium (FHD)**: Design moderno em modo escuro, otimizado para resoluções 1080p.
* **Sistema de Favoritos**: Salve seus canais e conteúdos favoritos para acesso rápido.
* **Auto-Recarregamento Inteligente**: O player tenta reconectar automaticamente até 3 vezes em caso de erro ou congelamento do stream.
* **Multi-idioma**: Totalmente localizado em Português (Brasil), Inglês e Espanhol.

## 🚀 Instalação (Modo Desenvolvedor)

Como este é um projeto de código aberto para Roku, você deve instalá-lo via modo de desenvolvedor:

1.  **Habilite o Modo Desenvolvedor** no seu Roku: Pressione `Home` (3x), `Cima` (2x), `Direita`, `Esquerda`, `Direita`, `Esquerda`, `Direita` no controle remoto.
2.  **Defina uma senha** e anote o endereço IP do seu dispositivo.
3.  **Baixe este repositório** e compacte o conteúdo da pasta (incluindo as pastas `source`, `components`, `images`, etc.) em um arquivo `.zip`.
4.  **Acesse o IP do Roku** no seu navegador, faça o upload do arquivo `.zip` e clique em "Install".

---

## 📂 Como Adicionar Sua Playlist

Existem três maneiras de configurar sua lista de canais no aplicativo:

### 1. Através da Interface do Aplicativo (Recomendado)
Dentro do aplicativo, você pode adicionar e gerenciar múltiplas listas:
* Pressione o botão **Asterisco (*)** no controle remoto para abrir o menu de seleção.
* Escolha entre **URL M3U** ou **API Xtream**.
* Utilize o teclado virtual para inserir seus dados de acesso (Servidor, Usuário e Senha).
* Você pode gerenciar e alternar entre diferentes playlists no menu "Gerenciar Playlists".

### 2. Envio Remoto (Via Terminal/ECP)
Você pode enviar uma URL de playlist diretamente do seu computador ou celular para o Roku enquanto o app está aberto ou para iniciá-lo:

```bash
curl -d "" "http://IP_DO_SEU_ROKU:8060/launch/dev?url=http://link-da-sua-lista.m3u"
```

## 🎮 Controles do Controle Remoto

* **Setas**: Utilizadas para navegar pelas categorias e listas de canais.
* **OK**: Inicia a reprodução de conteúdos (Ao Vivo/Filmes) ou entra na lista de episódios de uma série.
* **Asterisco (*)**: Abre o menu de seleção para alterar o provedor/credenciais ou alterna o status de **Favorito** do item selecionado.
* **Voltar (Back)**: Sai do modo de vídeo em tela cheia ou retorna ao menu/nível de navegação anterior.
* **Números 1-9**: Atalhos rápidos para reproduzir instantaneamente os itens salvos em sua lista de favoritos por índice.

## 🛠️ Notas Técnicas

* **User-Agent**: O player simula um navegador Chrome moderno para contornar bloqueios de provedores e evitar throttling de ISP.
* **Formatos**: Suporta nativamente `.ts` (MPEG-TS) para transmissões ao vivo e extensões como `.mp4` ou `.mkv` para conteúdos sob demanda (VOD).
* **Cache**: O sistema para API Xtream utiliza um cache local de 6 horas (21.600 segundos) para as categorias, otimizando o tempo de resposta inicial.

> **Aviso**: Este aplicativo é uma ferramenta de reprodução técnica e não fornece, inclui ou comercializa qualquer conteúdo de mídia. É responsabilidade exclusiva do usuário fornecer uma lista de reprodução (M3U ou Xtream) válida e legal.

# ⏰ SmartPonto — Sistema de Presença Inteligente via BLE

O **SmartPonto** é um aplicativo mobile desenvolvido em Flutter que automatiza o processo de chamadas e registro de presença em salas de aula utilizando a tecnologia **Bluetooth Low Energy (BLE)**. 

O projeto elimina a necessidade de chamadas de voz ou assinaturas em papel, dividindo-se em duas dinâmicas integradas em tempo real: o **Modo Aluno** e o **Modo Professor**.

---

# 📱 Preview

<p align="center">
  <img width="270" height="600" alt="Modo Aluno" src="https://github.com/user-attachments/assets/8480adf1-ba1c-4d52-b112-8b84469179d4" style="margin-right: 10px;" />
  <img width="270" height="600" alt="Modo Professor" src="https://github.com/user-attachments/assets/004026c4-2c94-406b-a227-2878885872ff" style="margin-right: 10px;" />
  <img width="270" height="600" alt="Lista de Alunos" src="https://github.com/user-attachments/assets/91f93e2a-5673-4563-8821-d948d819a0ac" />
</p>

---

# 🚀 Como Funciona (Arquitetura BLE)

O aplicativo altera seu comportamento de hardware dinamicamente baseado no perfil selecionado:

### 🎓 Modo Aluno (Transmissor/Peripheral)
* O aluno insere seu nome completo (limitado a 15 caracteres para otimização de payload).
* O dispositivo passa a agir como um **Periférico BLE**, transmitindo dados via pacotes de *Advertising* customizados.
* Os dados brutos são codificados em `Uint8List` através de um `Manufacturer ID` específico (`1234`) e uma chave de protocolo identificadora (`AULA`).

### 👨‍🏫 Modo Professor (Receptor/Central)
* O dispositivo assume o papel de **Central BLE**, iniciando um escaneamento contínuo de baixa latência em busca de sinais específicos do protocolo do app.
* **Cálculo de Distância por RSSI:** O app captura o indicador de força do sinal recebido (RSSI) e aplica uma fórmula matemática de perda de percurso no espaço livre para estimar, em metros, quão perto o aluno está do professor:
  $$\text{Distância} = 10^{\frac{\text{TxPower} - \text{RSSI}}{10 \cdot n}}$$
* A lista de presença é atualizada a cada **1 segundo**, ordenando automaticamente os alunos do mais próximo ao mais distante e removendo da lista aqueles que se afastaram ou saíram da sala (timeout de 5 segundos offline).

---

# 🛠️ Tecnologias e Bibliotecas Utilizadas

* **[Flutter](https://flutter.dev/)** — Framework multiplataforma de UI.
* **[Dart](https://dart.dev/)** — Linguagem de programação focada em performance cliente.
* **[flutter_ble_peripheral](https://pub.dev/packages/flutter_ble_peripheral)** — Responsável por transformar o smartphone do aluno em um transmissor de sinal publicável.
* **[flutter_blue_plus](https://pub.dev/packages/flutter_blue_plus)** — Responsável pelo escaneamento robusto e captação de pacotes BLE no modo professor.
* **Material Design 3** — Componentização visual moderna e responsiva (utilizando recursos como `ChoiceChip`, `Card` dinâmicos e feedbacks via `SnackBar`).

---

# ▶️ Como Executar o Projeto

> **Nota:** Por utilizar recursos nativos de hardware (Bluetooth), é altamente recomendado testar o projeto em **dois dispositivos físicos** (um agindo como professor e outro como aluno).

### 1. Requisitos Prévios
Certifique-se de ter o Flutter instalado e configurado em sua máquina (`flutter doctor`). No Android, o aplicativo solicitará permissões de **Localização Fina** e **Bluetooth**, necessárias para o escaneamento de dispositivos próximos.

### 2. Instalação e Execução

```bash
# Clone o repositório
git clone [https://github.com/GabryePatrickSoares/SmartPonto.git](https://github.com/GabryePatrickSoares/SmartPonto.git)

# Acesse a pasta do projeto
cd SmartPonto

# Instale as dependências pubspec
flutter pub get

# Execute o projeto no dispositivo conectado
flutter run

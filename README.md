# Skapa en Robust och Säker WordPress-Site med AWS EFS och RDS

Denna guide beskriver hur du bygger en skalbar och säker WordPress-miljö på AWS med Elastic File System (EFS) för filhantering och Relational Database Service (RDS) för databaslagring. Guiden är en vidareutveckling av vår tidigare guide för att bygga en hosting-miljö för en webbapplikation. Den nya miljön är designad för att vara både robust och skalbar.

## Förkrav

För att följa denna guide och skapa en robust, säker och skalbar hosting-miljö för WordPress, säkerställ att följande tjänster och applikationer är installerade och konfigurerade:

- **[Visual Studio Code](https://code.visualstudio.com/Download)**: Textredigerare för att hantera kod.
- **[Registrera ett AWS-konto](https://aws.amazon.com/free/)**: För att komma åt AWS-tjänster.
- **[AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)**: Kommandoradsverktyg för att interagera med AWS-tjänster (kan kräva installation av **[Python](https://www.python.org/downloads/)** för att fungera korrekt).

Notera att **AWS CLI** kan kräva installation av **Python** för att fungera beroende på ditt operativsystem och den version av CLI du använder.

### Verifiera installationen av AWS CLI

För att kontrollera att AWS CLI har installerats korrekt, kan du köra följande kommando i terminalen:

```bash
aws --version
```
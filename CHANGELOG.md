## 0.0.3

- **Novo Recurso (Android):** Suporte a `Discovery` para encontrar dispositivos novos (não pareados) ao redor.
- **Novo Recurso (Android):** Implementação de fluxo de pareamento (`createBond`) automático ao tentar conectar.
- **Melhoria:** Adicionado método `stopScan()` para interromper a busca antes da conexão, aumentando a estabilidade.
- **Melhoria:** Novo código de erro `PAIRING_INITIATED` para facilitar o feedback visual na UI durante o pareamento.
- **Ajuste (iOS):** Otimização na reconexão utilizando UUID e validação de características de escrita.

## 0.0.2

- Ajuste nos arquivos obrigatórios para publicação no pub.dev.
- Inclusão da licença MIT completa.
- Atualização do CHANGELOG removendo entradas TODO.
- Melhoria na documentação e metadados do pacote (homepage, repository, etc.).

## 0.0.1

- Primeira versão oficial do plugin.
- Suporte a escaneamento de dispositivos Bluetooth.
- Conexão e desconexão com impressoras térmicas.
- Envio de bytes RAW para impressão (compatível com ESC/POS).
- Compatível com Android 5.0+ e Android 12+ (Bluetooth Scan/Connect).
- Exemplo completo incluído no diretório `example/`.
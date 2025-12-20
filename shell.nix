{
  mkShell,

  eeprom-uploader,
  zasm,
  xxd,
}:
mkShell {
  packages = [
    eeprom-uploader
    zasm
    xxd
  ];
}

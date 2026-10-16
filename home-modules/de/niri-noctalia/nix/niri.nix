{
  config,
  myLib,
  ...
}:
myLib.program.mk {
  dir = ../niri;
  target = "niri";
  context = {terminal = config.apps.using.terminal;};
}

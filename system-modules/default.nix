{...}@inputs:
{
  common = import ./common.nix inputs;
  common-linux = import ./common-linux.nix inputs;
  de.plasma = import ./de/plasma inputs;
  secrets = import .secrets inputs;
}

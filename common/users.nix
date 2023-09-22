{ config, lib, pkgs, ... }:

{
  users.users.lukas = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [ "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDoO+UrsXqPkkRX7C/qNsfw7Hmly1JuZe+gdh+2RYNfjPotLMkTvyYs7YeUmm55tP+jD8PCElMiix9e2jPGbBMX6b90iAh58E6f+AEtRQmTXAJouyj+NzHqSdlLd8ULYBnDftgOC9EpixN+Gjr7v9gkqskt0tT2feff9K49LRtFCqSOMilhlOGJ4ph6yaQ3P1oMv+EFTkUf3zBzXN7QsRE4epm6pfoAUe3ZJ4LMvAb8ki/jB0ywZpXVTeHN5w5cSYSYojdbo4xqHakzFGsw+uikiVCKwW6YBFblbQD73mRnvZoW3c3+F4NtY0tWakUjSrI1gTeVhjyQ4qlXM6bibPUNu9ZukTa9BzKFc2vwiSk7FKqlAXRF4WBWE8h/s+Fj4NCzVP9ebXRffQ7TAUg80ObuCwQcRSPsofzaHrb+/K7rAiLh4GymJHLb9pN7fJ3si0oezBpuXT9O1utoFMTi4wrIwVaTZhpHDMm6oDv3ZK7tRDrUtqLnWDlDWJMPhxN/nTRCWsmBPUa62kaEr9HFGntq7uosuLGmyn87pyLcb1/1Q9Cr4n+3k7m2f2XEXRmWNLFXmk7An0qu5dwQTUUO74jJK/tqViF5Cx6+laVPLXEDc1ru8rCZ3Ze0JsJ8g667qFfFRdRvKrHw8IkYzlAmDjZAoRU03JkDDoMqfpN7bCMyGw== lukas@yoga" ];
  };

  users.users.netali = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOV4f3/OcNQIHqomvH0nGLDmXDlrO/u7JKE9Fgq2Vuqs me@netali.de" ];
  };

  users.users.schlagma = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDQD1kCdE0IWOt9Xg3J7PgkaDFQ1NWNRPM7dRy2R4sGm marc@schlagenhauf.net" ];
  };
}
{ config, lib, pkgs, ... }:

{
  users.users = {
    karim = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      openssh.authorizedKeys.keys = [ "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDIIW5JAOReayvcN9YIxIrq+8qB2zJz6QGsClnulxjkNMs6vugDOlkucEcAhxcfCyn8G4D76oaR41acTApe+UNVrzQ2Spb/Ph0rqgc5Sfbnhf2u1DIcHSK8P1wWLdZfPavxcmdnW4NO5k2x77lLPxWX/oLmAy4o33bjVvTA5NQeRs1qXteTSMA0Oj+2YmECPygcZvZlrnjeDkFDiQpB5PS6BY8Xs9vPRtDzdzI8wweIxBTmbjiPhKDPXJG15oYJDeqKQ7+0vZtkycUqehP1Uyz1gjAf5MdZDUCCNKZHS3GRA7iZAIvaLaUQM+1ma2fD3QGSkUH6a775ifeqaqCLJW1794sIDBoAO9NXkmy2cJ9DJAD3VJ+37LjSlukF8U2NxuEwMIJacirXvUbQxfec1ljcFalzSzAdEIjO1ro6Ocm3cuJF3TniHR47fH4AVSJ0rsXPgI5Nqq4qOUjkVp0mA8C1tsiaYO1GVNEmgNPvXOOdmwbIOg1Bf7p7lSo+zxh/XD5T82EvceSjF4pyrWCdX7BdbXikGlk2t/HF4U8q60eNf+svqoPAGUhXDBeKKXjycsHk5OJsbSeiAaws6z9rysMLgdccrKCAaaEyC2xFXaVfsNWxvl+K1qhCEy8I1a3u7JvPM4D7BcQmFoVIv1Dg2rxGvdqmEex1YvlZDj0Pn4YzEQ== karim.wagner@tu-ilmenau.de" ];
    };

    lukas = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      openssh.authorizedKeys.keys = [ "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDoO+UrsXqPkkRX7C/qNsfw7Hmly1JuZe+gdh+2RYNfjPotLMkTvyYs7YeUmm55tP+jD8PCElMiix9e2jPGbBMX6b90iAh58E6f+AEtRQmTXAJouyj+NzHqSdlLd8ULYBnDftgOC9EpixN+Gjr7v9gkqskt0tT2feff9K49LRtFCqSOMilhlOGJ4ph6yaQ3P1oMv+EFTkUf3zBzXN7QsRE4epm6pfoAUe3ZJ4LMvAb8ki/jB0ywZpXVTeHN5w5cSYSYojdbo4xqHakzFGsw+uikiVCKwW6YBFblbQD73mRnvZoW3c3+F4NtY0tWakUjSrI1gTeVhjyQ4qlXM6bibPUNu9ZukTa9BzKFc2vwiSk7FKqlAXRF4WBWE8h/s+Fj4NCzVP9ebXRffQ7TAUg80ObuCwQcRSPsofzaHrb+/K7rAiLh4GymJHLb9pN7fJ3si0oezBpuXT9O1utoFMTi4wrIwVaTZhpHDMm6oDv3ZK7tRDrUtqLnWDlDWJMPhxN/nTRCWsmBPUa62kaEr9HFGntq7uosuLGmyn87pyLcb1/1Q9Cr4n+3k7m2f2XEXRmWNLFXmk7An0qu5dwQTUUO74jJK/tqViF5Cx6+laVPLXEDc1ru8rCZ3Ze0JsJ8g667qFfFRdRvKrHw8IkYzlAmDjZAoRU03JkDDoMqfpN7bCMyGw== lukas@yoga" ];
    };

    mgnehr = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      openssh.authorizedKeys.keys = [ "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDHeN3gZDOCaQ70c29xHqYZrtUrwY3W5heiacaCk/vZppiENqMjcrKTmdM1YSLAKQAxcyiXZ5ocS/KGlJfb3npgDVEPwYCbFmWDEBkgbiohQWtP5LoPSVUleZTzI1yxx9d653JFbNx+YBzdrq6OCBRSqqHk2eRJ1Gi72F+I/TJYuRvnPGsuIAY/Ly20K3Uc8ATbr9N+7AziC9sSZnTBIVPP0PC1HL3fmnwqE8pArc++SEv87kEgINZcg7dcvC94qaFLPYk/gcT/yRWI+ggtTQXiNLfyXPLiqGx39+R3l4CQo1R4psoBGQf2gfXU2KAcODXHZ5cW+6Wh90BxuIeiof4j2Sb0dEadzWwF7HyyA2OXCsLtE4OOrWx2a2ghiwOwbVlpJiz+kzLfQ+vnnuYfZnQPPFitKuAN3i2bjacP/QmH6sX3jtQl19Xexq314lvGuyBLRl44fYhkau2WiK7j5OjmX7NlgcU0MVZ/onkkBfSTxgBSDBC4Qu31q05SGBlcFFJCNYMS4C0Bdjt27wiAkBeqbUgx1jre5aiW4lFdktcFQkB2ett13AFW52ZPc3VXrES3fSfet9NaY+NcVXRXAZIxQUQMJ3lvpS6KvB0ktl/ITus0HofMI4FKQGCN13HhtWJH0cR4J4RNOR+7/kEoBRwTRRDXTDS53lS5iF2bvzXtUw== michael@michael-xmg" ];
    };

    netali = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPqnMKa8BZmbRM2Oc4E8N9h9N26ABPLgPTketLNSK7l7 me@netali.de" ];
    };
    
    schlagma = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDQD1kCdE0IWOt9Xg3J7PgkaDFQ1NWNRPM7dRy2R4sGm marc@schlagenhauf.net" ];
    };
  };
}

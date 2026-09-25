base:
  "*":
    - rf-client
    - software-versions
    - git
    # Machine-specific overrides, created by bootstrap-robotframework.ps1 and never shipped with
    # the repo. Listed last so its values win over the defaults above.
    - rf-client-local


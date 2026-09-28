base:
  "*":
    - rf-client
    - software-versions
    - git
    # Client role (coding/execution), written by bootstrap-robotframework.ps1 and never shipped
    # with the repo
    - client-role
    # Machine-specific overrides, created by bootstrap-robotframework.ps1 and never shipped with
    # the repo. Listed last so its values win over the defaults above.
    - rf-client-local


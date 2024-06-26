## Example to to use aws codecommit credential-helper
#git_global_settings:
#  credential:
#    helper: '"!aws codecommit credential-helper $@"'
#    UseHttpPath: true
#    interactive: never

git_repos:
  Markdown-Cheatsheet:
    remote_url: https://github.com/lifeparticle
    target_dir: 'C:\temp\git'
    #branch: main

  robotframework-cookbook:
    remote_url: https://github.com/adrianyorke/
    target_dir: 'C:\temp\git'

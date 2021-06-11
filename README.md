# aws-admin

SSH administration container packed with AWS CLI v2, EKSCTL, ECS-CLI, Kubectl and other utilities for managing AWS services in an account. Optimized to be used with ECS and base on the latest **Fedora** image.

## Features
- It uses `ZSH` as main shell and the root folder is mounted in a EFS filesystem por persistance. `oh-my-zsh` can be installed later;
- Optimized to be used with `Visual Studio Code Insiders` with the `SSH - Remote` extension;
- Every time the container starts:
  - Updates the `authorized_keys` file with a Public SSH Key (Base64-encoded and Configured into the Task Definition as an Environment Variable);
  - Update a custom **Route 53** DNS record in a hosted zone with the **ECS Task** public IP (Configured into the Task Definition as Environment Variables);
  - Sync all the contents of the `/root` folder into an S3 backet as backup (No deletion);
  - Clean most of the contents in the folder `~/.vscode-server-insiders` preserving the folders `data` and `extensions`.

## Deployment Instructions
- TBD
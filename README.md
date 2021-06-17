# aws-admin

SSH administration container packed with various container utilities for managing AWS services. It runs inside a **ECS** *task* managed by a **ECS** *service*. It's build on top of the latest **Fedora** image.

## Features
- It uses [ZSH](https://www.zsh.org/) as main shell for root;
- The `/root` uses an **EFS** filesystem mount for userdata persistance;
- Optimized to be used with [Visual Studio Code Insiders](https://code.visualstudio.com/insiders/) with the [SSH - Remote](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-ssh) extension;
- It bundles a number of useful tools to work with containers focused in AWS services, like [AWS CLI v2](https://github.com/aws/aws-cli/tree/v2), [ECS-CLI](https://github.com/aws/amazon-ecs-cli), [EKSCTL](https://eksctl.io/), [KUBECTL (built by AWS)](https://docs.aws.amazon.com/eks/latest/userguide/install-kubectl.html), [HELM 3](https://helm.sh/), [K9S](https://github.com/derailed/k9s), [ARGO WORKFLOWS CLI](https://argoproj.github.io/argo-workflows/cli/) and [PODMAN REMOTE CLIENT](https://github.com/containers/podman/blob/master/docs/tutorials/remote_client.md). Also it bundles the utility scripts from [utils](utils/) into the `/usr/local/bin` directory;
- The `entrypoint.sh` features:
  - Syncs all the container *system environments* into `/root/.ssh/environment` file, allowing the SSH user to access the *task* metadata to assume the *task's IAM Role*.
  - The `authorized_keys` file is injected on `/root/.ssh` through **CloudFormation** as a *Base64-encoded* parameter in the *TaskDefinition* as a *system environment*.
  - Clean most of the contents from `/root/.vscode-server-insiders` preserving the `data` and `extensions` directories. This is useful because **Visual Studio Code Insiders** is updated frequently and every new version generate new directories and files.
  - Updates a custom **Route 53** *DNS "A" record* every time the container starts with the *public IP* assigned to it's **ECS** *task* using the *AWS CLI*. The *DNS "A" record* and the **Route 53** zone are supplied as **CloudFormation** parameters and injected into the container as *system environments*.
  - Syncs all the contents of the `/root` (without deletion) into a private **S3** bucket provisioned by **CloudFormation** for backup purposes.

## Deployment Instructions

- Prerequisites:
  - Generate a *new SSH key pair* (Or use an existing one) for container's `authorized_keys` file. This command can be used to output the Base64-encoded SSH Public Key: `cat .ssh/mykey.pub | base64 -w 0 && echo`;
  - Create a new **Route 53** zone with a *valid* public domain (or use an existing one) and get it's *ID*;
- Download [this](https://raw.githubusercontent.com/masteredward/aws-admin/main/cloudformation/admin-hub.yaml) **CloudFormation** template and create a *new stack* into the **AWS Management Console**: `CloudFormation > Create Stack > With new resouces (standard) > Upload a template file > Choose file`;
- Supply **ALL** the parameters requested and create the stack.
- Wait until the *Stack* status is *CREATE_COMPLETE*.
- Edit the file `~/.ssh/config` and create an entry for FQDN hostname using the *User* root and the proper SSH Private Key path as *IdentityFile*. It will look like this:
  ```
  Host aws-admin
    HostName aws-admin.domain.com
    User root
    # Since the container will generate new SSH host keys in every new version, alerting potential security breaches, it's useful to add the following lines:
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
  ```
- Go to **Visual Studio Code Insiders** `Press F1 > Remote-SSH: Connect to Host... > aws-admin`. Enjoy!
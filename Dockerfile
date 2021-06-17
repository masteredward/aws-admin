FROM fedora
ARG ARGO_CLI_VERSION="3.0.7"
ARG K9S_VERSION="0.24.10"
ARG KUBECTL_DEFAULT_VERSION="1.20"
ENV R53_ZONE_ID="ZXXXXXXXXXXXXXXXXXXXX" \
    R53_REC_HOST="admin-xxx.domain.com" \
    R53_REC_TTL="60" \
    AUTH_KEY_B64="Y2F0IH4vLnNzaC9hdXRob3JpemVkX2tleXMgfCBiYXNlNjQgLXcgMAo=" \
    S3_EFS_BACKUP="efs-backup-bucket"

# DNF packages
RUN dnf group install "C Development Tools and Libraries" -y \
  && dnf install zsh git unzip openssl podman-remote ruby-devel zlib-devel bind-utils python3-pip jq rsync openssh-server passwd nano dnf-plugins-core iproute procps-ng nmap iputils hostname net-tools htop iptraf-ng -y \
  && dnf config-manager --add-repo https://rpm.releases.hashicorp.com/fedora/hashicorp.repo \
  && dnf install packer -y \
  && dnf clean all

# PIP packages
RUN pip install --no-cache-dir boto3 cfn-lint Pygments

# colorls plugin
RUN gem install colorls

# AWS CLI v2 install (latest)
RUN curl -L https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o /tmp/awscli.zip \
  && unzip -q /tmp/awscli.zip -d /tmp \
  && /tmp/aws/install --update \
  && rm -rf awscli.zip /tmp/aws

# Argo CLI install (Uses ARG for version)
RUN curl -LO https://github.com/argoproj/argo/releases/download/v${ARGO_CLI_VERSION}/argo-linux-amd64.gz \
  && gunzip argo-linux-amd64.gz \
  && rm -f argo-linux-amd64.gz \
  && chmod +x argo-linux-amd64 \
  && mv ./argo-linux-amd64 /usr/local/bin/argo

# ECSCLI install (latest)
RUN curl -L https://amazon-ecs-cli.s3.amazonaws.com/ecs-cli-linux-amd64-latest -o /usr/local/bin/ecs-cli \
  && chmod +x /usr/local/bin/ecs-cli

# EKSCTL install (latest)
RUN curl -L https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_linux_amd64.tar.gz -o /tmp/eksctl.tar.gz \
  && tar xzf /tmp/eksctl.tar.gz -C /usr/local/bin \
  && rm -f /tmp/eksctl.tar.gz \
  && chmod +x /usr/local/bin/eksctl

# HELM v3 install (latest)
RUN curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash

# K9s install (Uses ARG for version - Not possible to use latest after version 0.24.10)
RUN mkdir /tmp/k9s \
  && curl -L https://github.com/derailed/k9s/releases/download/v${K9S_VERSION}/k9s_v${K9S_VERSION}_Linux_x86_64.tar.gz -o /tmp/k9s/k9s.tar.gz \
  && tar xvf /tmp/k9s/k9s.tar.gz -C /tmp/k9s \
  && mv /tmp/k9s/k9s /usr/local/bin \
  && rm -rf /tmp/k9s \
  && chmod +x /usr/local/bin/k9s

# AWS-built kubectl install (From 1.16 to 1.20 - Uses links from https://docs.aws.amazon.com/eks/latest/userguide/install-kubectl.html)
# Uses a symbolic link to change the current version. Defaults to ARG)
RUN curl -L https://amazon-eks.s3.us-west-2.amazonaws.com/1.20.4/2021-04-12/bin/linux/amd64/kubectl -o /usr/local/bin/kubectl-1.20 \
  && curl -L https://amazon-eks.s3.us-west-2.amazonaws.com/1.19.6/2021-01-05/bin/linux/amd64/kubectl -o /usr/local/bin/kubectl-1.19 \
  && curl -L https://amazon-eks.s3.us-west-2.amazonaws.com/1.18.9/2020-11-02/bin/linux/amd64/kubectl -o /usr/local/bin/kubectl-1.18 \
  && curl -L https://amazon-eks.s3.us-west-2.amazonaws.com/1.17.12/2020-11-02/bin/linux/amd64/kubectl -o /usr/local/bin/kubectl-1.17 \
  && curl -L https://amazon-eks.s3.us-west-2.amazonaws.com/1.16.15/2020-11-02/bin/linux/amd64/kubectl -o /usr/local/bin/kubectl-1.16 \
  && chmod +x /usr/local/bin/kubectl-* \
  && ln -s /usr/local/bin/kubectl-${KUBECTL_DEFAULT_VERSION} /usr/local/bin/kubectl

# SSH setup
RUN ssh-keygen -A && passwd -d root \
  && printf "\nPasswordAuthentication no\nPermitUserEnvironment yes\n" >> /etc/ssh/sshd_config

# Setting ZSH as default shell for root
RUN usermod -s /usr/bin/zsh root

# Entrypoint, utilities and final adjustments
COPY /entrypoint.sh /entrypoint.sh
COPY /utils/podman-build.sh /usr/local/bin/podman-build
COPY /utils/kubectl-version.sh /usr/local/bin/kubectl-version
COPY /utils/eks-endpoint.sh /usr/local/bin/eks-endpoint
RUN chmod +x /entrypoint.sh /usr/local/bin/podman-build /usr/local/bin/kubectl-version /usr/local/bin/eks-endpoint
EXPOSE 22
WORKDIR /root
CMD ["/entrypoint.sh"]
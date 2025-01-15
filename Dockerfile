FROM debian:bookworm AS sso-development

RUN apt-get update;

RUN apt-get install -y sudo git zsh wget vim;

RUN apt-get install -y openjdk-17-jdk maven;

ARG USERNAME=r2d2
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN groupadd --gid ${USER_GID} ${USERNAME};
RUN adduser --uid ${USER_UID} --gid ${USER_GID} --shell /bin/zsh --home /home/r2d2 $USERNAME;
RUN echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
  && chmod 0440 /etc/sudoers.d/$USERNAME

# ********************************************************
# * Anything else you want to do like clean up goes here *
# ********************************************************

USER $USERNAME

RUN wget https://github.com/robbyrussell/oh-my-zsh/raw/master/tools/install.sh -O - | zsh || true

# ================================================================== #
# Builder of theme jars                                              #
# ================================================================== #
FROM node:23 AS sso-theme-builder

RUN apt-get update && \
  apt-get install -y openjdk-17-jdk && \
  apt-get install -y maven;

ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
RUN corepack enable

WORKDIR /opt/app

COPY ./themes/web/package.json ./themes/web/pnpm-lock.yaml ./
RUN --mount=type=cache,id=pnpm,target=/pnpm/store pnpm install --frozen-lockfile
COPY ./themes/web/ ./

RUN pnpm build-keycloak-theme

# ================================================================== #
# Builder of keycloak with essential features                        #
# ================================================================== #
FROM quay.io/keycloak/keycloak:26.1 AS sso-builder

ENV KC_HEALTH_ENABLED=true
ENV KC_METRICS_ENABLED=false
ENV KC_FEATURES=docker,token-exchange,recovery-codes
ENV KC_DB=postgres
ENV KEYCLOAK_EXTRA_ARGS=-Dkeycloak.profile.feature.scripts=enabled

WORKDIR /opt/keycloak

# COPY --from=sso-theme-builder /opt/app/dist_keycloak/ladesa-ro-theme.jar /opt/keycloak/providers/

RUN /opt/keycloak/bin/kc.sh build --health-enabled=true

# ================================================================== #
# Runtime keycloak with theme and essential features                 #
# ================================================================== #
FROM quay.io/keycloak/keycloak:26.1 AS sso-runtime

WORKDIR /opt/keycloak
COPY --from=sso-builder /opt/keycloak/ /opt/keycloak/

ENTRYPOINT [ \
  "/opt/keycloak/bin/kc.sh", \
  "start", \
  "--spi-login-protocol-openid-connect-legacy-logout-redirect-uri=true", \
  "--optimized", \
  "--proxy=edge" \
  ]

FROM odoo:16.0

LABEL maintainer="Escodoo"

USER root

ARG DEBIAN_FRONTEND=noninteractive

# Clone OCA dependency repos — each addon is copied into /mnt/extra-addons/
# which the base odoo image already includes in addons_path
RUN apt-get update && \
    apt-get install -y --no-install-recommends git && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir -p /tmp/oca && \
    # Clone repos needed by custom addons
    git clone --depth 1 --branch 16.0 https://github.com/OCA/mis-builder.git /tmp/oca/mis-builder && \
    git clone --depth 1 --branch 16.0 https://github.com/OCA/server-tools.git /tmp/oca/server-tools && \
    git clone --depth 1 --branch 16.0 https://github.com/OCA/account-financial-tools.git /tmp/oca/account-financial-tools && \
    git clone --depth 1 --branch 16.0 https://github.com/OCA/account-payment.git /tmp/oca/account-payment && \
    git clone --depth 1 --branch 16.0 https://github.com/OCA/account-invoicing.git /tmp/oca/account-invoicing && \
    git clone --depth 1 --branch 16.0 https://github.com/OCA/bank-statement-reconcile.git /tmp/oca/bank-statement-reconcile && \
    git clone --depth 1 --branch 16.0 https://github.com/OCA/l10n-brazil.git /tmp/oca/l10n-brazil && \
    git clone --depth 1 --branch 16.0 https://github.com/OCA/sale-workflow.git /tmp/oca/sale-workflow && \
    # Copy needed sub-addons from monorepos into extra-addons
    for repo_dir in /tmp/oca/*/; do \
        for addon_dir in "$repo_dir"*/; do \
            if [ -f "$addon_dir/__manifest__.py" ]; then \
                addon_name=$(basename "$addon_dir"); \
                cp -r "$addon_dir" "/mnt/extra-addons/${addon_name}"; \
            fi; \
        done; \
    done && \
    rm -rf /tmp/oca && \
    pip install --no-cache-dir psycogreen watchdog

# Copy custom addons (this repo) — each module into extra-addons
COPY --chown=odoo:odoo . /tmp/custom-repo/
RUN for dir in /tmp/custom-repo/*/; do \
        if [ -f "$dir/__manifest__.py" ]; then \
            addon_name=$(basename "$dir"); \
            cp -r "$dir" "/mnt/extra-addons/${addon_name}"; \
        fi; \
    done && \
    rm -rf /tmp/custom-repo

# Runtime entrypoint that generates odoo.conf from env vars
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Memory limits for free-tier hosting
ENV ODOO_RC=/etc/odoo/odoo.conf

ENTRYPOINT ["/entrypoint.sh"]
CMD ["odoo"]

USER odoo

EXPOSE 8069

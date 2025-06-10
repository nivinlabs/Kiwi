# checkov:skip=CKV_DOCKER_7:Ensure the base image uses a non latest version tag
FROM registry.access.redhat.com/ubi9-minimal

# Install system dependencies
RUN microdnf -y module enable nginx:1.22 && \
    microdnf -y --nodocs install python3.11 mariadb-connector-c libpq \
    nginx-core sscg tar glibc-langpack-en && \
    microdnf -y --nodocs update && \
    microdnf clean all

# Set environment variables
ENV PATH=/venv/bin:${PATH} \
    VIRTUAL_ENV=/venv \
    LC_ALL=en_US.UTF-8 \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US.UTF-8

# Create virtual environment and install Python dependencies
RUN python3.11 -m venv /venv && \
    /venv/bin/pip install --upgrade pip

# Copy requirements.txt and install Python packages
COPY requirements.txt /tmp/
RUN /venv/bin/pip install --no-cache-dir -r /tmp/requirements.txt

# Copy scripts and app files
COPY ./httpd-foreground /httpd-foreground
COPY ./manage.py /Kiwi/
COPY ./etc/*.conf /Kiwi/etc/
COPY ./etc/cron.jobs/* /Kiwi/etc/cron.jobs/

# Create necessary directories
RUN mkdir -p /Kiwi/ssl /Kiwi/static /Kiwi/uploads /Kiwi/etc/cron.jobs

# Generate self-signed SSL certificate
RUN /usr/bin/sscg -v -f \
    --country BG --locality Sofia \
    --organization "Kiwi TCMS" \
    --organizational-unit "Quality Engineering" \
    --ca-file       /Kiwi/static/ca.crt     \
    --cert-file     /Kiwi/ssl/localhost.crt \
    --cert-key-file /Kiwi/ssl/localhost.key

# Configure Django settings and SSL links
RUN sed -i "s/tcms.settings.devel/tcms.settings.product/" /Kiwi/manage.py && \
    ln -s /Kiwi/ssl/localhost.crt /etc/pki/tls/certs/localhost.crt && \
    ln -s /Kiwi/ssl/localhost.key /etc/pki/tls/private/localhost.key

# Run Django collectstatic
RUN /venv/bin/python /Kiwi/manage.py collectstatic --noinput --link

# Set permissions
RUN chown -R 1001 /Kiwi/ /venv/

# Expose ports and configure healthcheck
HEALTHCHECK CMD curl --fail -k -H "Referer: healthcheck" https://127.0.0.1:8443/accounts/login/
EXPOSE 8080
EXPOSE 8443

# Run as non-root
USER 1001

# Start server
CMD /httpd-foreground

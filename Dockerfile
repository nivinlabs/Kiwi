FROM registry.access.redhat.com/ubi9-minimal

RUN microdnf -y module enable nginx:1.22 && \
    microdnf -y --nodocs install python3.11 mariadb-connector-c libpq \
    nginx-core sscg tar glibc-langpack-en && \
    microdnf -y --nodocs update && \
    microdnf clean all

ENV PATH=/venv/bin:${PATH} \
    VIRTUAL_ENV=/venv      \
    LC_ALL=en_US.UTF-8     \
    LANG=en_US.UTF-8       \
    LANGUAGE=en_US.UTF-8

# Create virtualenv and install dependencies
RUN python3.11 -m venv /venv && \
    /venv/bin/pip install --upgrade pip

# Add requirements if needed
# COPY requirements.txt .
# RUN /venv/bin/pip install -r requirements.txt

COPY ./httpd-foreground /httpd-foreground
COPY ./manage.py /Kiwi/
COPY ./etc/*.conf /Kiwi/etc/
COPY ./etc/cron.jobs/* /Kiwi/etc/cron.jobs/

RUN mkdir -p /Kiwi/ssl /Kiwi/static /Kiwi/uploads /Kiwi/etc/cron.jobs

# Generate SSL cert
RUN /usr/bin/sscg -v -f \
    --country BG --locality Sofia \
    --organization "Kiwi TCMS" \
    --organizational-unit "Quality Engineering" \
    --ca-file       /Kiwi/static/ca.crt     \
    --cert-file     /Kiwi/ssl/localhost.crt \
    --cert-key-file /Kiwi/ssl/localhost.key

RUN sed -i "s/tcms.settings.devel/tcms.settings.product/" /Kiwi/manage.py && \
    ln -s /Kiwi/ssl/localhost.crt /etc/pki/tls/certs/localhost.crt && \
    ln -s /Kiwi/ssl/localhost.key /etc/pki/tls/private/localhost.key

# Static files and permissions
RUN /Kiwi/manage.py collectstatic --noinput --link
RUN chown -R 1001 /Kiwi/ /venv/

HEALTHCHECK CMD curl --fail -k -H "Referer: healthcheck" https://127.0.0.1:8443/accounts/login/
EXPOSE 8080
EXPOSE 8443
USER 1001
CMD /httpd-foreground

# Pinned by digest; Renovate proposes new digests
FROM myoung34/github-runner:latest@sha256:e42bd25e1e79f98813411c34f3dca036c52eb11e4e75eb96787436ba8c04c3a8

# Install Claude Code Review dependencies
USER root

# Workflows run `python3` and import the SDK. Ubuntu's system Python refuses pip installs (PEP 668), and pip can't
# upgrade the packages apt put there, so the SDK goes in a venv first on PATH that still sees the system packages
RUN python3 -m venv --system-site-packages /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
# renovate: datasource=pypi depName=anthropic
RUN pip install --no-cache-dir anthropic==2.8.0

# Copy initialization script
COPY scripts/init-runner.sh /opt/init-runner.sh
RUN chmod +x /opt/init-runner.sh

# Create wrapper entrypoint that runs init before starting runner
COPY scripts/entrypoint-wrapper.sh /opt/entrypoint-wrapper.sh
RUN chmod +x /opt/entrypoint-wrapper.sh

# The container stays root on purpose: the base entrypoint refuses to start under
# a non-root USER while RUN_AS_ROOT=true (its default) and exits on every boot.
# Set RUN_AS_ROOT=false to have it drop to the runner user itself via gosu.

# Use wrapper entrypoint
ENTRYPOINT ["/opt/entrypoint-wrapper.sh"]

# Setting ENTRYPOINT clears the CMD inherited from the base image, so restate it.
# Without it the entrypoint registers the runner, has nothing to run, and exits.
CMD ["./bin/Runner.Listener", "run", "--startuptype", "service"]

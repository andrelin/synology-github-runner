# Pinned by digest; Renovate proposes new digests
FROM myoung34/github-runner:latest@sha256:bfd4ead648d58c3672e7c3cc4f791df5542f02b3d60aa8e8e2cd099707bb6944

# Install Claude Code Review dependencies
USER root

# Install Anthropic SDK (0.72.0 is the last release for the base image's Python 3.8)
# renovate: datasource=pypi depName=anthropic
RUN pip3 install --no-cache-dir anthropic==0.72.0

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

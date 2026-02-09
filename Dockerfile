FROM myoung34/github-runner:latest

# Install Claude Code Review dependencies
USER root

# Install Anthropic SDK
RUN pip3 install --no-cache-dir anthropic

# Copy initialization script
COPY scripts/init-runner.sh /opt/init-runner.sh
RUN chmod +x /opt/init-runner.sh

# Create wrapper entrypoint that runs init before starting runner
COPY scripts/entrypoint-wrapper.sh /opt/entrypoint-wrapper.sh
RUN chmod +x /opt/entrypoint-wrapper.sh

# Switch back to runner user
USER runner

# Use wrapper entrypoint
ENTRYPOINT ["/opt/entrypoint-wrapper.sh"]

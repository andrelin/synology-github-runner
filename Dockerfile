FROM myoung34/github-runner:latest

# Install Claude Code Review dependencies
USER root

# Install Anthropic SDK
RUN pip3 install --no-cache-dir anthropic

# Switch back to runner user
USER runner

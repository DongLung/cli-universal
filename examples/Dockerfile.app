# Example: Application image based on cli-universal
# For running a Python application directly

FROM cli-universal:python3.12

# Install application dependencies
COPY requirements.txt /app/
WORKDIR /app
RUN uv pip install --system -r requirements.txt

# Copy application
COPY . /app/

# Override entrypoint to run app directly
# This bypasses the menu system
ENTRYPOINT []
CMD ["python3", "main.py"]

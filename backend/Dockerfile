# Step 1: Start with an official Python base image.
FROM python:3.12-slim

# Step 2: Set the working directory inside the container.
WORKDIR /app

# Step 3: Copy our project's requirements file into the container.
COPY requirements.txt .

# Step 4: Install the Python dependencies from the requirements file.
RUN python3 -m pip install --no-cache-dir -r requirements.txt

# Step 5: Copy all of our application code into the container.
COPY . .

# Step 6: Tell Docker that our application will run on port 8000.
EXPOSE 8000

# Step 7: Define the command to run when the container starts.
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
from flask import Flask

app = Flask(__name__)

@app.route("/")
def home():
    return "Worker service is running"

@app.route("/health")
def health():
    return {"status": "healthy", "service": "worker"}

@app.route("/process")
def process():
    return {"status": "processed"}

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5001)
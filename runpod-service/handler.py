import runpod

# 🔥 Load models ONCE (important for performance)
print("Loading models...")
# example:
# yolo_model = load_yolo()
# sam_model = load_sam()

def handler(event):
    input_data = event.get("input", {})

    prompt = input_data.get("prompt", "")
    image_url = input_data.get("image_url")

    print(f"Received: {prompt}")

    # 🔥 Your pipeline here
    # result = run_yolo_sam_pipeline(image_url, prompt)

    result = {
        "message": f"Processed prompt: {prompt}",
        "image_url": image_url
    }

    return result


runpod.serverless.start({
    "handler": handler
})
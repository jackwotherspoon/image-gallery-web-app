from google.cloud import storage, vision

storage_client = storage.Client()
vision_client = vision.ImageAnnotatorClient()

# run object detection on image
def detect_objects(data):
    file_data = data

    file_name = file_data["name"]
    bucket_name = file_data["bucket"]

    blob_uri = f"gs://{bucket_name}/{file_name}"
    blob_source = vision.Image(source=vision.ImageSource(image_uri=blob_uri))

    print(f"Analyzing {file_name}.")

    objects = vision_client.object_localization(
        image=blob_source
    ).localized_object_annotations

    print(f"Number of objects detected: {len(objects)}")

    for object in objects:
        print(f"Object: {object.name}, Confidence: {object.score})")

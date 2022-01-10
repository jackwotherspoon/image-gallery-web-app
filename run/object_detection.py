from google.cloud import storage, vision
import firebase_admin
from firebase_admin import credentials, firestore

creds = credentials.ApplicationDefault()
firebase_admin.initialize_app(creds)

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

    # create dict to keep track of counts of same objects found
    object_dict = dict()

    # add detected objects to dict
    for object in objects:
        print(f"Object: {object.name}, Confidence: {round(object.score, 2)}")
        object_dict[(object.name).lower()] = (
            object_dict.get((object.name).lower(), 0) + 1
        )

    # write object detection results to firestore db
    data = {
        "image_name": str(file_name),
        "detections": object_dict,
        "image_url": f"https://storage.googleapis.com/{bucket_name}/{file_name}",
    }
    try:
        db = firestore.client()
        db.collection("images").document(file_name).set(data)
        print(f"Data sent to database!")
    except:
        print(f"Failed to connect to Database.")

    return

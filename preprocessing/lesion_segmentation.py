import cv2
import numpy as np
import matplotlib.pyplot as plt

# ---------- LOAD IMAGE ----------
import sys
image_path = sys.argv[1] if len(sys.argv) > 1 else "samples/example.jpg"
image = cv2.imread(image_path)
image_rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)

# ---------- STEP 1: LAB + CLAHE ----------
lab = cv2.cvtColor(image, cv2.COLOR_BGR2LAB)
L, A, B = cv2.split(lab)

clahe = cv2.createCLAHE(clipLimit=3.0, tileGridSize=(8, 8))
L_eq = clahe.apply(L)

lab_eq = cv2.merge((L_eq, A, B))
image_eq = cv2.cvtColor(lab_eq, cv2.COLOR_LAB2RGB)

# ---------- STEP 2: K-MEANS CLUSTERING ----------
Z = image_eq.reshape((-1, 3))
Z = np.float32(Z)

criteria = (cv2.TERM_CRITERIA_EPS + cv2.TERM_CRITERIA_MAX_ITER, 20, 1.0)
K = 3  # background, mucosa, lesion
_, labels, centers = cv2.kmeans(Z, K, None, criteria, 10, cv2.KMEANS_RANDOM_CENTERS)

segmented = centers[labels.flatten()].reshape(image_eq.shape).astype(np.uint8)
label_image = labels.reshape(image_eq.shape[:2])

# ---------- STEP 3: SELECT CLUSTER THAT LOOKS LIKE LESION ----------
# Choose cluster with lowest average 'a' (green-red channel in LAB) -> tends to be whitish/pale
cluster_means = []
for k in range(K):
    mask_k = (label_image == k)
    cluster_means.append(np.mean(A[mask_k]))
lesion_cluster = np.argmin(cluster_means)

mask = np.uint8(label_image == lesion_cluster) * 255

# ---------- STEP 4: CLEAN MASK ----------
kernel = np.ones((5, 5), np.uint8)
mask_clean = cv2.morphologyEx(mask, cv2.MORPH_OPEN, kernel, iterations=2)
mask_clean = cv2.morphologyEx(mask_clean, cv2.MORPH_CLOSE, kernel, iterations=2)

# ---------- STEP 5: KEEP LARGEST CONNECTED REGION ----------
num_labels, labels_cc, stats, _ = cv2.connectedComponentsWithStats(mask_clean, connectivity=8)
if num_labels > 1:
    largest_label = 1 + np.argmax(stats[1:, cv2.CC_STAT_AREA])
    mask_main = np.uint8(labels_cc == largest_label) * 255
else:
    mask_main = mask_clean

# ---------- STEP 6: DRAW BOUNDING BOX ----------
coords = cv2.findNonZero(mask_main)
x, y, w, h = cv2.boundingRect(coords)
image_boxed = image_rgb.copy()
cv2.rectangle(image_boxed, (x, y), (x+w, y+h), (0, 255, 0), 3)

result = cv2.bitwise_and(image_rgb, image_rgb, mask=mask_main)

# ---------- PLOT RESULTS ----------
plt.figure(figsize=(14, 6))

plt.subplot(1, 3, 1)
plt.title("Input (CLAHE Enhanced)")
plt.imshow(image_eq)
plt.axis("off")

plt.subplot(1, 3, 2)
plt.title("Lesion Mask")
plt.imshow(mask_main, cmap='gray')
plt.axis("off")

plt.subplot(1, 3, 3)
plt.title("Final Detection with Box")
plt.imshow(image_boxed)
plt.axis("off")

plt.tight_layout()
plt.show()

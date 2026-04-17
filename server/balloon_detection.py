import kagglehub
import os
import cv2
import numpy as np
from typing import List, Tuple, Dict
import json
import base64
from pathlib import Path

class BalloonDetector:
    def __init__(self):
        self.datasets = {}
        self.load_datasets()
        
    def load_datasets(self):
        """Download and load balloon detection datasets from Kaggle"""
        try:
            # Download balloon object detection datasets
            datasets = [
                "serhiibiruk/balloon-object-detection",
                "vbookshelf/v2-balloon-detection-dataset", 
                "mashlyn/balloons-data-set-uci"
            ]
            
            for dataset in datasets:
                try:
                    print(f"Downloading dataset: {dataset}")
                    path = kagglehub.dataset_download(dataset)
                    self.datasets[dataset] = path
                    print(f"Path to dataset files: {path}")
                except Exception as e:
                    print(f"Failed to download {dataset}: {e}")
                    
        except Exception as e:
            print(f"Error loading datasets: {e}")
    
    def detect_balloons(self, image_data: bytes) -> Dict:
        """
        Detect balloons in image using template matching and color detection
        Returns detection results with bounding boxes
        """
        try:
            # Convert bytes to numpy array
            nparr = np.frombuffer(image_data, np.uint8)
            img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
            
            if img is None:
                return {"error": "Could not decode image"}
            
            # Convert to different color spaces for better detection
            hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
            
            # Define balloon color ranges (red, blue, yellow, green, etc.)
            color_ranges = [
                # Red balloons
                ([0, 120, 70], [10, 255, 255]),
                ([170, 120, 70], [180, 255, 255]),
                # Blue balloons  
                ([100, 150, 50], [130, 255, 255]),
                # Yellow balloons
                ([20, 100, 100], [30, 255, 255]),
                # Green balloons
                ([40, 50, 50], [80, 255, 255]),
                # Pink/Purple balloons
                ([140, 50, 50], [170, 255, 255])
            ]
            
            detections = []
            
            for lower, upper in color_ranges:
                # Create mask for color range
                mask = cv2.inRange(hsv, np.array(lower), np.array(upper))
                
                # Find contours
                contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
                
                for contour in contours:
                    # Filter by area to remove noise
                    area = cv2.contourArea(contour)
                    if area > 500:  # Minimum balloon size
                        # Get bounding box
                        x, y, w, h = cv2.boundingRect(contour)
                        
                        # Calculate circularity (balloons are roughly circular)
                        perimeter = cv2.arcLength(contour, True)
                        if perimeter > 0:
                            circularity = 4 * np.pi * area / (perimeter * perimeter)
                            
                            # Only include if reasonably circular
                            if circularity > 0.3:
                                detections.append({
                                    'class': 'balloon',
                                    'confidence': min(0.9, circularity),
                                    'bbox': {
                                        'x': int(x),
                                        'y': int(y), 
                                        'width': int(w),
                                        'height': int(h)
                                    },
                                    'area': int(area),
                                    'circularity': float(circularity)
                                })
            
            # Non-maximum suppression to remove overlapping detections
            filtered_detections = self._non_max_suppression(detections)
            
            return {
                'detections': filtered_detections,
                'count': len(filtered_detections),
                'image_shape': {
                    'height': img.shape[0],
                    'width': img.shape[1],
                    'channels': img.shape[2] if len(img.shape) > 2 else 1
                }
            }
            
        except Exception as e:
            return {"error": f"Detection failed: {str(e)}"}
    
    def _non_max_suppression(self, detections: List[Dict], iou_threshold: float = 0.3) -> List[Dict]:
        """Apply non-maximum suppression to remove overlapping detections"""
        if not detections:
            return []
        
        # Sort by confidence
        detections.sort(key=lambda x: x['confidence'], reverse=True)
        
        keep = []
        while detections:
            # Keep the highest confidence detection
            current = detections.pop(0)
            keep.append(current)
            
            # Remove overlapping detections
            remaining = []
            for detection in detections:
                if self._calculate_iou(current['bbox'], detection['bbox']) < iou_threshold:
                    remaining.append(detection)
            
            detections = remaining
        
        return keep
    
    def _calculate_iou(self, box1: Dict, box2: Dict) -> float:
        """Calculate Intersection over Union (IoU) between two bounding boxes"""
        # Calculate intersection
        x1 = max(box1['x'], box2['x'])
        y1 = max(box1['y'], box2['y'])
        x2 = min(box1['x'] + box1['width'], box2['x'] + box2['width'])
        y2 = min(box1['y'] + box1['height'], box2['y'] + box2['height'])
        
        if x2 <= x1 or y2 <= y1:
            return 0.0
        
        intersection = (x2 - x1) * (y2 - y1)
        
        # Calculate union
        area1 = box1['width'] * box1['height']
        area2 = box2['width'] * box2['height']
        union = area1 + area2 - intersection
        
        return intersection / union if union > 0 else 0.0
    
    def get_dataset_info(self) -> Dict:
        """Get information about loaded datasets"""
        info = {}
        for name, path in self.datasets.items():
            if path and os.path.exists(path):
                files = []
                for root, dirs, filenames in os.walk(path):
                    for filename in filenames:
                        if filename.lower().endswith(('.jpg', '.jpeg', '.png', '.xml', '.txt')):
                            files.append(filename)
                
                info[name] = {
                    'path': path,
                    'files': files[:10],  # Show first 10 files
                    'total_files': len(files)
                }
        
        return info

# Flask integration for API endpoint
def create_balloon_detection_api(app):
    """Add balloon detection API endpoints to Flask app"""
    
    @app.route('/api/balloon-detect', methods=['POST'])
    def detect_balloons():
        try:
            from flask import request, jsonify
            
            if 'image' not in request.files:
                return jsonify({'error': 'No image provided'}), 400
            
            file = request.files['image']
            if file.filename == '':
                return jsonify({'error': 'No file selected'}), 400
            
            # Read image
            image_data = file.read()
            
            # Create detector and run detection
            detector = BalloonDetector()
            result = detector.detect_balloons(image_data)
            
            if 'error' in result:
                return jsonify({'error': result['error']}), 500
            
            return jsonify(result)
            
        except Exception as e:

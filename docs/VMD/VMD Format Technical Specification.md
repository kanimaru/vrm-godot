# **VMD (Vocaloid Motion Data) Format Specification**

This document provides a deep-dive technical reference for the VMD binary format, specifically focusing on the relationship between motion data and the model's rest state.

## **1\. Global Standards**

* Endianness: Little-endian.  
* Floats: 32-bit IEEE 754\.  
* Strings: Shift-JIS (CP932).  
* Coordinates: Left-Handed (X+ Right, Y+ Up, Z+ Forward).

## **2\. The Concept of "Rest Position" (Bind Pose)**

A VMD file does not contain absolute world coordinates for bones. It contains **offsets** relative to the model's initial state (defined in the PMD or PMX file).

### **2.1 Position Offsets**

* In VMD: A position value of (0.0, 0.0, 0.0) means the bone is exactly at its rest position as defined in the model file.  
* Calculation: Final Local Position \= Rest Position (from PMX) \+ VMD Offset.  
* Implementation Note: Most bones in MikuMikuDance (except the "Mother" or "Center" bones) have their position locked. Even if a VMD contains position data for an arm bone, MMD will usually ignore it unless the model's bone is explicitly set to allow translation.

### **2.2 Rotation Offsets**

* In VMD: A rotation is an orientation relative to the bone's rest orientation.  
* Identity: The identity quaternion (0.0, 0.0, 0.0, 1.0) represents "no rotation," meaning the bone maintains the exact angle defined in the rest pose.  
* Hierarchy Impact: Because MMD uses a hierarchical bone system, a rotation applied to a "Shoulder" bone physically moves the "Elbow" and "Hand" bones. The VMD data for the Elbow is then applied relative to that new inherited orientation.

## **3\. Advanced Rotation Mechanics**

### **3.1 Bone Quaternions (x, y, z, w)**

* Storage: 4 floats (16 bytes).  
* Math: MMD uses the formula q\_final \= q\_rest \* q\_vmd. However, since most rest poses in MMD have an identity rotation (0,0,0,1), the VMD quaternion usually acts as the local rotation directly.  
* Normalization: You must ensure the quaternion is normalized (length equals 1.0). If the length is not 1.0, interpolation will produce visual jitter or "shrinking" artifacts.

### **3.2 Camera Euler Angles**

* Format: 3 floats (x, y, z).  
* Behavior: Unlike bones, cameras do not have a "rest pose" in a separate file. Their "rest" is simply looking at the Target (0,0,0) from the default distance.  
* Gimbal Lock: Because cameras use Euler angles instead of Quaternions, they are susceptible to gimbal lock at vertical extremes (90 degree pitch). VMD handles this by using specific Bezier interpolation on the Euler components to smooth the transition.

## **4\. Binary Layout (Enriched)**

### **4.1 Header (50 bytes)**

* 30 bytes: Magic ("Vocaloid Motion Data 0002\\0").  
* 20 bytes: Model Name.

### **4.2 Bone Data (111 bytes per record)**

* 15 bytes: Bone Name (Shift-JIS).  
* 4 bytes: Frame (uint32).  
* 12 bytes: Position Offset (float x, y, z).  
* 16 bytes: Rotation Offset (float x, y, z, w \- Quaternion).  
* 64 bytes: Interpolation.

### **4.3 IK and Visibility (The "IK Switch")**

This section is critical for leg and arm logic.

* Visible: 1 byte (0 \= hidden, 1 \= shown).  
* IK Count: 4 bytes (uint32).  
* IK List: For each bone:  
  * Name: 20 bytes (Shift-JIS).  
  * Status: 1 byte (0 \= IK Off, 1 \= IK On).  
* Implementation Detail: When IK is "Off," the model ignores the IK solver and relies solely on the bone rotations for that limb. When "On," the IK solver overrides manual rotations for the child bones in the chain.

## **5\. Interpolation Logic (Bezier)**

### **5.1 Grid Mapping**

* Points: P0(0,0), P1(x1, y1), P2(x2, y2), P3(127,127).  
* Note: Values in the file are 0-127. Normalize these to 0.0-1.0 by dividing by 127.0 before performing cubic Bezier calculations.

### **5.2 Track Mapping (64-byte block)**

This is the most common area for parsing errors.

* Track 1 (X-Pos): Bytes 0, 4, 8, 12  
* Track 2 (Y-Pos): Bytes 1, 5, 9, 13  
* Track 3 (Z-Pos): Bytes 2, 6, 10, 14  
* Track 4 (Rotation): Bytes 3, 7, 11, 15  
* Bytes 16-63: Historically used to store the same data but offset by 1 byte for internal MMD memory alignment. They should be ignored for reading.

## **6\. Implementation Checklist**

1. Read Header and check version.  
2. Read Bone keyframes \-\> Sort by frame number.  
3. Read Morph keyframes \-\> Sort by frame number.  
4. Read Camera keyframes \-\> Sort by frame number.  
5. Implementation: To find the state at Frame 15 when keyframes only exist at 10 and 20:  
   * Identify the two bounding keyframes.  
   * Calculate t (0.5 in this case).  
   * Pass t through the Bezier curve defined by the interpolation bytes.  
   * Use the resulting 'eased t' to Lerp (linear interpolate) the position and Slerp (spherical linear interpolate) the rotation quaternion.
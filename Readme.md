# decalShader
This is a decal shader on a mesh which be rendered like a standard shader.

# Licence
This project is licensed under WTFPL. (same as code referenced)

If there is a notation in the file, that takes precedence.

# Reference
### Base: https://light11.hatenadiary.com/entry/2020/02/22/181705
### UnityDocs

# How to use
1. Place your model in a Unity scene. ->BaseModel  
2. Create a new material, change the shader to Custom/DecalShader_VRC, and assign a texture. ->DecalMaterial  
3. Add an empty Gameobject as a child of BaseModel. ->DecalObject  
4. Add a mesh filter and meshrenderer to DecalObject, change the mesh to your model, and assign DecalMaterial to DecalObject material.  
5. Add an empty Gameobject as a child of DecalObject. ->DecalProjectorObject  
6. Add ProjectorInput and ProjectorInputUdon, and assign DecalMaterial to ProjectorInput/Material.  
7. adjust Position(move DecalProjectorObject position)/FOV/Near/Far/Ortho/Persp  

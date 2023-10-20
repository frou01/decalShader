# decalShader
This is decal shader on an mesh which be rendered like standard shader.

# Licence
This project licensed under WTFPL. (same as code referenced)

# Reference
### Base : https://light11.hatenadiary.com/entry/2020/02/22/181705
### UnityDocs

# How to use
1.Place your model to an unity scene. ->BaseModel
2.Create a new material, change the shader to Custom/DecalShader_VRC and assign texture. ->DecalMaterial
3.Add an empty Gameobject as child of BaseModel. ->DecalObject
4.Add mesh filter and meshrenderer to DecalObject, change mesh to your model and assign DecalMaterial.
5.Add an empty Gameobject as child of DecalObject. ->DecalProjectorObject
6.Add ProjectorInput and ProjectorInputUdon, and assign DecalMaterial to ProjectorInput/Material.
7.adjust Position(move DecalProjectorObject position)/FOV/Near/Far/Ortho/Persp

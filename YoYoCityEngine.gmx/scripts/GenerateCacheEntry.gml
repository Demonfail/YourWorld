/// MeshA = GenerateCacheEntry(GridCellX,GridCellY)
//
//  Generate a Mesh array entry for a grid cell, and return and array holding the mesh and poly count
//
//
var gx = argument0;
var gy = argument1;

//show_debug_message("Cache: ("+string(gx)+","+string(gy)+")");
var Mesh = vertex_create_buffer_ext(512*1024);
var SpriteMesh = vertex_create_buffer_ext(8*1024);
var RoadArrowsMesh = vertex_create_buffer_ext(8*1024);

// Get map bounds.
var x1 = gx*GridCacheSize;
var y1 = gy*GridCacheSize;
var x2 = x1+GridCacheSize;
var y2 = y1+GridCacheSize;

// Start poly counting
var polys = global.polys;
var spritepolys=0;
var roadpolys = 0;

// keep local for faster access
var blockinfo = block_info;
var themap = Map;
var thesprites = Sprites;
vertex_begin(RoadArrowsMesh, global.SpriteFormat);
vertex_begin(SpriteMesh, global.SpriteFormat);
vertex_begin(Mesh, global.CityFormat);

{
        global.cubes = 0;
        WSize = MapWidth*TileSize;
        HSize = MapHeight*TileSize;
        CubeEdge = TileSize;
        sp = CubeEdge;
      
        y = -y1*TileSize;
        for (var yy=y1; yy<y2; yy++)
        {
             x = x1*TileSize;
             for (var xx=x1; xx<x2; xx++)
             {
                // Look up column
                var u, d, l, r, lid, base, block, a, z, len; 
                
                var col = (yy*(MapDepth*MapWidth))+(xx*MapDepth);
                
                a = ds_grid_get(themap, xx, yy);                          

                z = 0;
                len = array_length_1d(a);
                minimapColor = 2;
                
                for(var zz=0; zz<len; zz++)
                {
                    block = a[zz];      // read block_info index out of column
                    if (block > 0)
                    {
                        // if not empty
                        var info = blockinfo[block];
                        l = info[BLK_LEFT];
                        r = info[BLK_RIGHT];
                        t = info[BLK_TOP];
                        b = info[BLK_BOTTOM];
                        lid=info[BLK_LID];
                        base=info[BLK_BASE];
                        var flags = info[BLK_FLAGS1];
                        //if (keyboard_check(vk_insert))
                            //show_debug_message(string(col+(zz|$80000000)));

                        AddCube(Mesh, x, y-CubeEdge, z, x+CubeEdge, y, z+CubeEdge, col+(zz|$80000000), t, b, l, r, lid, base, flags);
                        
                        // Update the mini-map
                        // JO: Slightly crude. TOFIX
                        //if (zz == len-1)
                            //{
                            //if (instance_exists(objMinimap))
                                //{
                                // Road
                                if (lid >= 65 && lid <=83)
                                || (lid >= 84 && lid <=102)
                                    minimapColor = 4;
                                    
                                // Building
                                else if (lid >= 13 && lid <=15)
                                     || (lid >= 17 && lid <=28)
                                     || (lid >= 41 && lid <=53)
                                     || (lid >= 29 && lid <=40)
                                     || (lid >= 103 && lid <=117)
                                    minimapColor = 1;
                                    
                                // Grass
                                else if (lid == 5)
                                     || (lid == 6)
                                     || (lid == 54)
                                     || (lid == 55)
                                     || (lid == 56)
                                    minimapColor = 3;
                                    
                                // Pavement
                                else if (lid == 7 || lid == 16)
                                     || (zz > 3)
                                    minimapColor = 0;
                                //}
                            //}
                        
                        // Add road arrows if they exist
                        var roadFlags = (flags>>22)&$F;
                        if (roadFlags)
                            {
                            AddRoadArrow(RoadArrowsMesh, sprRoadArrows, 0, x, y, z, 1, 1, 0, $ffffffff, roadFlags);
                            roadpolys += 2;
                            }
                            
                        // Add pedestrian markers if they exist
                        var pedFlag = (flags>>26)&1;
                        if (pedFlag)
                            {
                            AddPavementTile(RoadArrowsMesh, sprRoadArrows, 0, x, y, z, 1, 1, 0, $ffffffff, pedFlag);
                            roadpolys += 2;
                            }
                    }
                    z-=sp;
                }
                
                
                // Update the mini-map
                // JO: Slightly crude. TOFIX
                //if (zz == len-1)
                    //{
                    if (instance_exists(objMinimap))
                        {
                        draw_set_alpha(1.0);
                        d3d_set_lighting(false);
                        surface_set_target(objMinimap.surface);                                    
                        d3d_set_projection_ortho(0, 0, 1024, 1024, 0);
                        
                        draw_sprite(sprPoint, minimapColor, xx, yy);
                        
                        surface_reset_target();
                        SetProjection(global.Camera);
                        }
                    //}
                
                
                // Now do all sprites in this column
                a = ds_grid_get(thesprites,xx,yy);
                   
                if (is_array(a))
                    {
                    // if its an array, then there are sprites here.
                    var l = array_length_1d(a);
                    for (var i=0; i<l; i++)
                        {
                        var s = a[i];
                        var image = DecalGetImage(s[0]);
                        var sxx = x+(s[1]&$ff);
                        var syy = y- ((s[1]&$ff00)>>8);
                        var szz = ((s[1]>>16)&$ffff);
                        AddSprite(SpriteMesh, image,0,sxx,syy,szz, 1,1,0, col+(i|$80000000));
                        spritepolys += 2;
                        }
                    }
                x += sp;
                }
             y -= sp;
      }
}
x = 0;
y = 0;

vertex_end(Mesh);
vertex_end(SpriteMesh);
vertex_end(RoadArrowsMesh);


// Finish world mesh
var polys = global.polys - polys;
if (polys == 0)
    {
    vertex_delete_buffer(Mesh);
    Mesh = -1;
    }
else
    vertex_freeze(Mesh);


// Finish sprites mesh
if (spritepolys == 0)
    {
    vertex_delete_buffer(SpriteMesh);
    SpriteMesh = -1;
    }
else
    vertex_freeze(SpriteMesh);


// Finish road arrows + peds mesh
if (roadpolys == 0)
    {
    vertex_delete_buffer(RoadArrowsMesh);
    RoadArrowsMesh = -1;
    }
else
    vertex_freeze(RoadArrowsMesh);


// Compile all meshes into array and return that array
// JO: Bit weird as there is another mesh at 3 after total poly count at 2. TOFIX
var MeshA = 0;
MeshA[3] = RoadArrowsMesh;
MeshA[2] = spritepolys + roadpolys + polys;
MeshA[1] = SpriteMesh;
MeshA[0] = Mesh;
return MeshA;


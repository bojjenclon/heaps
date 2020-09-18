package hxd.res;

import haxe.ds.StringMap;
#if (haxe_ver < 4)
import haxe.xml.Fast in Access;
#else
import haxe.xml.Access;
#end

typedef TiledMapTileset =
{
  var name : String;
  var firstGid : Int;
  var tileWidth : Int;
  var tileHeight : Int;
  var spacing : Int;
  var margin : Int;
  var tileCount : Int;
  var columns : Int;

  var image : String;
};

typedef TiledMapObject =
{
  x : Int,
  y : Int,
  name : String,
  type : String
};

typedef TiledMapLayer =
{
  var data : Array<Int>;
  var name : String;
  var opacity : Float;
  var objects : Array<TiledMapObject>;
  var properties : StringMap<String>;
}

typedef TiledMapData =
{
  var width : Int;
  var height : Int;
  var tilesets : Array<TiledMapTileset>;
  var layers : Array<TiledMapLayer>;
}

class TiledMap extends Resource
{
  static final BASE = new haxe.crypto.BaseCode(haxe.io.Bytes.ofString("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"));

  public function toMap() : TiledMapData
  {
    var data = entry.getBytes().toString();
    var rootNode = new Access(Xml.parse(data).firstElement());

    var tilesets : Array<TiledMapTileset> = new Array<TiledMapTileset>();
    for (ts in rootNode.nodes.tileset)
    {
      tilesets.push({
        name: ts.att.name,
        firstGid: Std.parseInt(ts.att.firstgid),
        tileWidth: Std.parseInt(ts.att.tilewidth),
        tileHeight: Std.parseInt(ts.att.tileheight),
        spacing: ts.has.spacing ? Std.parseInt(ts.att.spacing) : 0,
        margin: ts.has.margin ? Std.parseInt(ts.att.margin) : 0,
        tileCount: Std.parseInt(ts.att.tilecount),
        columns: Std.parseInt(ts.att.columns),

        image: '${entry.path.substring(0, entry.path.length - entry.name.length - 1)}/${ts.node.image.att.source}'
      });
    }

    var layers : Array<TiledMapLayer> = new Array<TiledMapLayer>();
    for (layer in rootNode.nodes.layer)
    {
      layers.push(processLayer(layer));
    }

    for (group in rootNode.nodes.objectgroup)
    {
      layers.push(processObjectGroup(group));
    }

    for (group in rootNode.nodes.group)
    {
      processGroup(group, layers);
    }

    return {
      width: Std.parseInt(rootNode.att.width),
      height: Std.parseInt(rootNode.att.height),
      tilesets: tilesets,
      layers: layers,
    };
  }

  function processLayer(layer : Access) : TiledMapLayer
  {
    var data = StringTools.trim(layer.node.data.innerData);
    while (data.charCodeAt(data.length - 1) == "=".code)
    {
      data = data.substr(0, data.length - 1);
    }

    var bytes = haxe.io.Bytes.ofString(data);
    bytes = BASE.decodeBytes(bytes);
    bytes = format.tools.Inflate.run(bytes);

    var input = new haxe.io.BytesInput(bytes);

    var data = [];
    for (_ in 0...bytes.length >> 2)
    {
      data.push(input.readInt32());
    }

		var properties = new StringMap<String>();
    if (layer.hasNode.properties)
		{
      for (prop in layer.node.properties.nodes.property)
      {
        properties.set(prop.att.name, prop.att.value);
      }
		}

    return {
      name: layer.att.name,
      opacity: layer.has.opacity ? Std.parseFloat(layer.att.opacity) : 1.,
      objects: [],
      properties: properties,
      data: data,
    };
  }

  function processObjectGroup(group : Access) : TiledMapLayer
  {
    var objects : Array<TiledMapObject> = new Array<TiledMapObject>();
    for (obj in group.nodes.object)
    {
      if (obj.has.name)
      {
        objects.push({
          name: obj.att.name,
          type: obj.has.type ? obj.att.type : null,
          x: Std.parseInt(obj.att.x),
          y: Std.parseInt(obj.att.y)
        });
      }
    }

		var properties = new StringMap<String>();
		if (group.hasNode.properties)
		{
			for (prop in group.node.properties.nodes.property)
			{
				properties.set(prop.att.name, prop.att.value);
			}
		}

    return {
      name: group.att.name,
      opacity: 1.,
      objects: objects,
      properties: properties,
      data: null,
    };
  }

  function processGroup(groupNode : Access, layers : Array<TiledMapLayer>, ?sharedProps : StringMap<String>)
  {
		// Merge properties from group level down into child nodes
    var properties = sharedProps == null ? new StringMap<String>() : sharedProps.copy();
		if (groupNode.hasNode.properties)
		{
      for (prop in groupNode.node.properties.nodes.property)
      {
        properties.set(prop.att.name, prop.att.value);
      }
		}
    
    for (layer in groupNode.nodes.layer)
    {
      var layer = processLayer(layer);
      for (key in properties.keys())
      {
        layer.properties.set(key, properties.get(key));
      }
      layers.push(layer);
    }

    for (group in groupNode.nodes.objectgroup)
    {
      var layer = processObjectGroup(group);
      for (key in properties.keys())
      {
        layer.properties.set(key, properties.get(key));
      }
      layers.push(layer);
    }

    for (group in groupNode.nodes.group)
    {
      processGroup(group, layers, properties);
    }
  }
}

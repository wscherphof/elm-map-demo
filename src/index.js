import './main.css';
import { Elm } from './Main.elm';
import registerServiceWorker from './registerServiceWorker';

var app = Elm.Main.init({
  node: document.getElementById('root')
});

registerServiceWorker();

(function dom() {
  app.ports.dom.subscribe(function(msg) {
    switch (msg.Cmd) {
      case 'SelectText':
        selectText(msg.id);
        break;
    }

    function selectText(id) {
      var element = document.getElementById(id);
      if (element && element.select) {
        element.select();
      }
    }
  });
})();

(function map() {
  app.ports.map.subscribe(function(msg) {
    switch (msg.Cmd) {
      case 'Fly':
        fly(msg.lon, msg.lat);
        break;
    }
  });

  function mapCenter(coordinate, there) {
    app.ports.mapCenter.send({
      lon: coordinate[0],
      lat: coordinate[1],
      there: there
    });
  }
  
  const flyTime = 2000;
  function fly(lon, lat) {
    var coordinate = ol.proj.fromLonLat([lon, lat]);
    var view = getMap().getView();
    var width = getMap().getSize()[0];
    if (ol.sphere.getDistance(coordinate, view.getCenter()) > width / 100) {
      elmMove = true;
      view.animate({
        center: coordinate,
        duration: flyTime
      });
      var zoom = view.getZoom();
      view.animate({
        zoom: zoom - 1,
        duration: flyTime / 2
      }, {
        zoom: zoom,
        duration: flyTime / 2
      });
    }
  }
  
  function singleclick(event) {
    var coordinate = ol.proj.toLonLat(event.coordinate);
    mapCenter(coordinate, false);
  }
  
  var elmMove = false;
  function moveend() {
    if (elmMove) {
      elmMove = false;
    } else {
      var coordinate = ol.proj.toLonLat(getMap().getView().getCenter());
      mapCenter(coordinate, true);
    }
  }

  var _map;
  function getMap() {
    if (!_map) {
      _map = new ol.Map({
        target: 'map',
        layers: [
            new ol.layer.Tile({
                source: new ol.source.OSM()
            })
        ],
        view: new ol.View({
            center: ol.proj.fromLonLat([0, 0]),
            zoom: 15
        })
      });
      _map.on('singleclick', singleclick);
      _map.on('moveend', moveend);
    }
    return _map;
  }
})();
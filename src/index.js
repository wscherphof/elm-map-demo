import './main.css';
import { Elm } from './Main.elm';
import registerServiceWorker from './registerServiceWorker';

var app = Elm.Main.init({
  node: document.getElementById('root')
});

registerServiceWorker();

(function port_map() {
  function moveend() {
    var coordinate = ol.proj.toLonLat(getMap().getView().getCenter());
    app.ports.mapMoved.send({
      lon: coordinate[0],
      lat: coordinate[1]
    });
  }
  
  app.ports.map.subscribe(function(msg) {
    switch (msg.Cmd) {
      case 'Fly':
        fly(msg.lon, msg.lat);
        break;
    }
  });

  function singleclick(event) {
    var coordinate = ol.proj.toLonLat(event.coordinate);
    fly(coordinate[0], coordinate[1]);
  }
  
  function fly(lon, lat) {
    var coordinate = ol.proj.fromLonLat([lon, lat]);
    var view = getMap().getView();
    var width = getMap().getSize()[0];
    view.animate({
      center: coordinate,
      duration: 300
    });
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

(function port_dom() {
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

// keep touching the visor icon from scrolling the app
document.getElementById('icon-visor').addEventListener('touchmove', function(event) {
  event.preventDefault();
});

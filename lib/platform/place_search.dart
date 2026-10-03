class PlaceSearchBridge {
  PlaceSearchBridge(this.onSelected);
  final void Function(double latitude, double longitude, String name, String address) onSelected;
  void initialize() {}
  void dispose() {}
}

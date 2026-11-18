/// The pages with a first-visit spotlight tour (lib/ui/spotlight_tour.dart).
/// The ids are saved in the profile: never change them.
enum PageTour {
  levels('levels'),
  workshop('workshop'),
  gadgets('gadgets'),
  stats('stats');

  const PageTour(this.id);

  final String id;

  static PageTour? byId(String id) {
    for (final tour in values) {
      if (tour.id == id) {
        return tour;
      }
    }
    return null;
  }
}

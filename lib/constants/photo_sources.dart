class PhotoSources {
  static const albums = 'albums';
  static const binders = 'binders';
  static const notebooks = 'notebooks';
  static const photosOnly = 'photosOnly';
  
  static String getScreenTitle(String source) {
    switch (source) {
      case binders:
        return 'Binders';
      case notebooks:
        return 'Notebooks';
      case photosOnly:
        return 'Photos';
      case albums:
      default:
        return 'Albums';
    }
  }
} 
import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';
import '../../common/pd_file_specification.dart';
import '../../pd_document.dart';
import 'pd_annotation_markup.dart';

/// This is the class that represents a file attachment.
class PDAnnotationFileAttachment extends PDAnnotationMarkup {
  /// See get/setAttachmentName.
  static const String attachmentNamePushPin = 'PushPin';

  /// See get/setAttachmentName.
  static const String attachmentNameGraph = 'Graph';

  /// See get/setAttachmentName.
  static const String attachmentNamePaperclip = 'Paperclip';

  /// See get/setAttachmentName.
  static const String attachmentNameTag = 'Tag';

  /// The type of annotation.
  static const String subType = 'FileAttachment';

  /// Constructor.
  PDAnnotationFileAttachment([COSDictionary? field])
      : super(field ?? COSDictionary()) {
    if (field == null) {
      dictionary.setName(COSName.subtype, subType);
    }
  }

  /// Return the attached file.
  PDFileSpecification? getFile() {
    return PDFileSpecification.fromCOS(dictionary.getDictionaryObject(COSName.fs));
  }

  /// Set the attached file.
  void setFile(PDFileSpecification file) {
    dictionary.setItem(COSName.fs, file);
  }

  /// This is the name used to draw the type of attachment. See the ATTACHMENT_NAME_XXX constants.
  String getAttachmentName() {
    return dictionary.getNameAsString(COSName.nameKey, attachmentNamePushPin) ??
        attachmentNamePushPin;
  }

  /// Set the name used to draw the attachment icon. See the ATTACHMENT_NAME_XXX constants.
  void setAttachmentName(String name) {
    dictionary.setName(COSName.nameKey, name);
  }

  // TODO: setCustomAppearanceHandler, constructAppearances
  void constructAppearances([PDDocument? document]) {
    // Implement PDFileAttachmentAppearanceHandler logic when handlers are ported
  }
}

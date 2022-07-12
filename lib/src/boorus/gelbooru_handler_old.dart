import 'dart:convert';
import 'dart:math';
import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:html/parser.dart';
import 'package:xml/xml.dart';

import 'package:lolisnatcher/src/handlers/booru_handler.dart';
import 'package:lolisnatcher/src/data/booru_item.dart';
import 'package:lolisnatcher/src/data/booru.dart';
import 'package:lolisnatcher/src/data/comment_item.dart';
import 'package:lolisnatcher/src/data/note_item.dart';
import 'package:lolisnatcher/src/data/tag.dart';
import 'package:lolisnatcher/src/data/tag_type.dart';
import 'package:lolisnatcher/src/utils/tools.dart';
import 'package:lolisnatcher/src/utils/logger.dart';

/// Booru Handler for the gelbooru engine
class GelbooruHandlerOld extends BooruHandler {
  GelbooruHandlerOld(Booru booru, int limit) : super(booru, limit);

  @override
  bool hasSizeData = true;

  @override
  Map<String, TagType> tagTypeMap = {
    "5": TagType.meta,
    "3": TagType.copyright,
    "4": TagType.character,
    "1": TagType.artist,
    "0": TagType.none
  };

  @override
  Map<String, String> getHeaders() {
    return {
      "Accept": "text/html,application/xml,application/json",
      "user-agent": Tools.appUserAgent(),
      "Cookie": "fringeBenefits=yup;" // unlocks restricted content (but it's probably not necessary)
    };
  }

  @override
  void parseResponse(response) {
    // bool isXML = response.body.contains("<posts>");
    if(booru.baseURL!.contains("://realbooru.com")){
      return;
    }
    bool isJSON = false;
    try {
      // TODO is it possible to get the confirmation that response is JSON without trying to parse it?
      var json = jsonDecode(response.body);
      isJSON = true;
    } catch (e) {
      isJSON = false;
    }

    List<BooruItem> newItems = [];
    if (isJSON) {
      newItems = parseJsonResponse(response);
    } else {
      newItems = parseXmlResponse(response);
    }
    afterParseResponse(newItems);
  }

  @override
  void afterParseResponse(List<BooruItem> newItems) {
    int lengthBefore = fetched.length;
    fetched.addAll(newItems);
    populateTagHandler(newItems);
    setMultipleTrackedValues(lengthBefore, fetched.length);
  }

  List<BooruItem> parseJsonResponse(response) {
    var parsedResponse = jsonDecode(response.body);
    // gelbooru: { post: [...] }, others [post, ...]
    List posts = (response.body.contains("@attributes") ? parsedResponse["post"] : parsedResponse) ?? [];
    List<BooruItem> newItems = [];

    for (int i = 0; i < posts.length; i++) {
      var current = posts.elementAt(i);
      Logger.Inst().log(current, className, "parseJsonResponse", LogTypes.booruHandlerRawFetched);
      try {
        if (current["file_url"] != null) {
          // Fix for bleachbooru
          String fileURL = "", sampleURL = "", previewURL = "";
          fileURL += current["file_url"]!.toString();
          // sample url is optional, on gelbooru there is sample == 0/1 to tell if it exists
          sampleURL += current["sample_url"]?.toString() ?? current["file_url"]!.toString();
          previewURL += current["preview_url"]!.toString();
          if (!fileURL.contains("http")) {
            fileURL = booru.baseURL! + fileURL;
            sampleURL = booru.baseURL! + sampleURL;
            previewURL = booru.baseURL! + previewURL;
          }

          BooruItem item = BooruItem(
            fileURL: fileURL,
            sampleURL: sampleURL,
            thumbnailURL: previewURL,
            // parseFragment to parse html elements (i.e. &amp; => &)
            tagsList: parseFragment(current["tags"]).text?.split(" ") ?? [],
            postURL: makePostURL(current["id"]!.toString()),
            fileWidth: double.tryParse(current["width"]?.toString() ?? ''),
            fileHeight: double.tryParse(current["height"]?.toString() ?? ''),
            sampleWidth: double.tryParse(current["sample_width"]?.toString() ?? ''),
            sampleHeight: double.tryParse(current["sample_height"]?.toString() ?? ''),
            previewWidth: double.tryParse(current["preview_width"]?.toString() ?? ''),
            previewHeight: double.tryParse(current["preview_height"]?.toString() ?? ''),
            hasNotes: current["has_notes"]?.toString() == 'true',
            // TODO rule34xxx api bug? sometimes (mostly when there is only one comment) api returns empty array
            hasComments: current["has_comments"]?.toString() == 'true',
            serverId: current["id"]?.toString(),
            rating: current["rating"]?.toString(),
            score: current["score"]?.toString(),
            sources: (current["source"].runtimeType == String) ? [current["source"]!] : null,
            md5String: current["md5"]?.toString(),
            postDate: current["created_at"]?.toString(), // Fri Jun 18 02:13:45 -0500 2021
            postDateFormat: "EEE MMM dd HH:mm:ss  yyyy", // when timezone support added: "EEE MMM dd HH:mm:ss Z yyyy",
          );
          newItems.add(item);
        }
      } catch (e) {
        Logger.Inst().log(e.toString(), className, "parseResponse", LogTypes.exception);
      }
    }

    return newItems;
  }

  dynamic getAttrOrElem(XmlElement item, String key) {
    return isGelbooru() ? item.getElement(key)?.innerText : item.getAttribute(key);
  }

  List<BooruItem> parseXmlResponse(response) {
    var parsedResponse = XmlDocument.parse(response.body);
    // gelbooru: <post><file_url>...</file_url></post>, others <post file_url="..." />
    var posts = parsedResponse.findAllElements('post');
    List<BooruItem> newItems = [];

    for (int i = 0; i < posts.length; i++) {
      var current = posts.elementAt(i);
      Logger.Inst().log(posts.elementAt(i).toString(), className, "parseXmlResponse", LogTypes.booruHandlerRawFetched);
      try {
        if (getAttrOrElem(current, "file_url") != null) {
          // Fix for bleachbooru
          String fileURL = "", sampleURL = "", previewURL = "";
          fileURL += getAttrOrElem(current, "file_url")!.toString();
          // sample url is optional, on gelbooru there is sample == 0/1 to tell if it exists
          sampleURL += getAttrOrElem(current, "sample_url")?.toString() ?? getAttrOrElem(current, "file_url")!.toString();
          previewURL += getAttrOrElem(current, "preview_url")!.toString();
          if (!fileURL.contains("http")) {
            fileURL = booru.baseURL! + fileURL;
            sampleURL = booru.baseURL! + sampleURL;
            previewURL = booru.baseURL! + previewURL;
          }

          BooruItem item = BooruItem(
            fileURL: fileURL,
            sampleURL: sampleURL,
            thumbnailURL: previewURL,
            tagsList: parseFragment(getAttrOrElem(current, "tags")).text?.split(" ") ?? [],
            postURL: makePostURL(getAttrOrElem(current, "id")!.toString()),
            fileWidth: double.tryParse(getAttrOrElem(current, "width")?.toString() ?? ''),
            fileHeight: double.tryParse(getAttrOrElem(current, "height")?.toString() ?? ''),
            sampleWidth: double.tryParse(getAttrOrElem(current, "sample_width")?.toString() ?? ''),
            sampleHeight: double.tryParse(getAttrOrElem(current, "sample_height")?.toString() ?? ''),
            previewWidth: double.tryParse(getAttrOrElem(current, "preview_width")?.toString() ?? ''),
            previewHeight: double.tryParse(getAttrOrElem(current, "preview_height")?.toString() ?? ''),
            hasNotes: getAttrOrElem(current, "has_notes")?.toString() == 'true',
            // TODO rule34xxx api bug? sometimes (mostly when there is only one comment) api returns empty array
            hasComments: getAttrOrElem(current, "has_comments")?.toString() == 'true',
            serverId: getAttrOrElem(current, "id")?.toString(),
            rating: getAttrOrElem(current, "rating")?.toString(),
            score: getAttrOrElem(current, "score")?.toString(),
            sources: getAttrOrElem(current, "source") != null ? [getAttrOrElem(current, "source")!] : null,
            md5String: getAttrOrElem(current, "md5")?.toString(),
            postDate: getAttrOrElem(current, "created_at")?.toString(), // Fri Jun 18 02:13:45 -0500 2021
            postDateFormat: "EEE MMM dd HH:mm:ss  yyyy", // when timezone support added: "EEE MMM dd HH:mm:ss Z yyyy",
          );

          newItems.add(item);
        }
      } catch (e) {
        Logger.Inst().log(e.toString(), className, "parseResponse", LogTypes.exception);
      }
    }

    return newItems;
  }

  @override
  String makePostURL(String id) {
    return "${booru.baseURL}/index.php?page=post&s=view&id=$id";
  }

  @override
  String makeURL(String tags, {bool forceXML=false}) {
    int cappedPage = max(0, pageNum);
    String isJson = isGelbooru() && !forceXML ? "&json=1" : "&json=0";

    if (booru.apiKey == "") {
      return "${booru.baseURL}/index.php?page=dapi&s=post&q=index&tags=${tags.replaceAll(" ", "+")}&limit=${limit.toString()}&pid=${cappedPage.toString()}$isJson";
    } else {
      return "${booru.baseURL}/index.php?api_key=${booru.apiKey}&user_id=${booru.userID}&page=dapi&s=post&q=index&tags=${tags.replaceAll(" ", "+")}&limit=${limit.toString()}&pid=${cappedPage.toString()}$isJson";
    }
  }

  // ----------------- Tag suggestions and tag handler stuff

  @override
  String makeTagURL(String input) {
    String isJson = isGelbooru() ? "&json=1" : "&json=0";
    // 16.01.22 - r34xx has order=count&direction=desc, but only it has it, so not worth adding it
    if (isNotGelbooru()) {
      return "${booru.baseURL}/autocomplete.php?q=$input"; // doesn't allow limit, but sorts by popularity
    } else {
      return "${booru.baseURL}/index.php?page=dapi&s=tag&q=index&name_pattern=$input%&limit=10$isJson";
    }
  }

  // @override
  // Future fetchTagSuggestions(Uri uri, String input) {
  //   // xml
  //   // return http.get(uri, headers: {"Accept": "text/html,application/xml", "user-agent": Tools.appUserAgent()});

  //   // json
  //   return http.get(uri, headers: {"Accept": "application/json", "user-agent": Tools.appUserAgent()});
  // }

  @override
  List parseTagSuggestionsList(response) {
    // xml
    // var parsedResponse = XmlDocument.parse(response.body);
    // return parsedResponse.findAllElements("tag") as List;

    // json
    var parsedResponse = (isGelbooru() ? jsonDecode(response.body)["tag"] : jsonDecode(response.body)) ?? [];
    return parsedResponse;
  }

  @override
  String? parseTagSuggestion(responseItem, int index) {
    // xml
    // return responseItem.getAttribute("name")?.trim();

    // json
    return responseItem[isGelbooru() ? "name" : "value"];
  }

  @override
  String makeDirectTagURL(List<String> tags) {
    String isJson = isGelbooru() ? "&json=1" : "&json=0";
    return "${booru.baseURL}/index.php?page=dapi&s=tag&q=index&names=${tags.join(" ")}&limit=500$isJson";
  }

  @override
  Future<List<Tag>> genTagObjects(List<String> tags) async{
    List<Tag> tagObjects = [];
    Logger.Inst().log("Got tag list: $tags", className, "genTagObjects", LogTypes.booruHandlerTagInfo);
    String url = makeDirectTagURL(tags);
    Logger.Inst().log("DirectTagURL: $url", className, "genTagObjects", LogTypes.booruHandlerTagInfo);
    Uri uri = Uri.parse(url);
    if (isGelbooru()) {
      try {
        final response = await http.get(uri, headers: {"Accept": "application/json", "user-agent": Tools.appUserAgent()});
        // 200 is the success http response code
        if (response.statusCode == 200) {
          var parsedResponse = (isGelbooru() ? jsonDecode(response.body)["tag"] : jsonDecode(response.body)) ?? [];
          if (parsedResponse?.isNotEmpty ?? false) {
            Logger.Inst().log("Tag response length: ${parsedResponse.length},Tag list length: ${tags.length}", className, "genTagObjects", LogTypes.booruHandlerTagInfo);
            for (int i = 0; i < parsedResponse.length; i++) {
              String fullString = parseFragment(isGelbooru() ? parsedResponse.elementAt(i)["name"] : parsedResponse.elementAt(i)["value"]).text!;
              String typeKey = parsedResponse.elementAt(i)["type"].toString();
              TagType? tagType = TagType.none;
              if (tagTypeMap.containsKey(typeKey)) tagType = (tagTypeMap[typeKey] ?? TagType.none);
              if (fullString.isNotEmpty){
                tagObjects.add(Tag(fullString, tagType: tagType));
              }
            }
          }
        }
      } catch (e) {
        Logger.Inst().log(e.toString(), className, "tagSearch", LogTypes.exception);
      }
    }
    return tagObjects;
  }

  // ----------------- Search count

  @override
  Future<void> searchCount(String input) async {
    int result = 0;
    // gelbooru json has count in @attributes, but there is no count data on r34xxx json, so we switch back to xml
    String url = makeURL(input);

    try {
      Uri uri = Uri.parse(url);
      final response = await http.get(uri, headers: getHeaders());
      // 200 is the success http response code
      if (response.statusCode == 200) {
        if (response.body.contains("@attributes")) {
          var parsedResponse = jsonDecode(response.body);
          result = parsedResponse["@attributes"]["count"];
        } else {
          var parsedResponse = XmlDocument.parse(response.body);
          var root = parsedResponse.findAllElements('posts').toList();
          if (root.length == 1) {
            result = int.parse(root[0].getAttribute('count') ?? '0');
          }
        }
      }
    } catch (e) {
      Logger.Inst().log(e.toString(), className, "searchCount", LogTypes.exception);
    }
    totalCount.value = result;
    return;
  }

  // ----------------- Comments

  @override
  bool hasCommentsSupport = true;

  @override
  String makeCommentsURL(String postID, int pageNum) {
    return "${booru.baseURL}/index.php?page=dapi&s=comment&q=index&post_id=$postID";
  }

  @override
  List parseCommentsList(response) {
    var parsedResponse = XmlDocument.parse(response.body);
    return parsedResponse.findAllElements("comment") as List;
  }

  @override
  CommentItem? parseComment(responseItem, int index) {
    var current = responseItem;
    String? avatar = isGelbooru()
        ? (current.getAttribute("creator_id")!.isEmpty
            ? "${booru.baseURL}/user_avatars/avatar_${current.getAttribute("creator")}.jpg"
            : "${booru.baseURL}/user_avatars/honkonymous.png")
        : null;

    return CommentItem(
      id: current.getAttribute("id"),
      title: current.getAttribute("id"),
      content: current.getAttribute("body"),
      authorID: current.getAttribute("creator_id"),
      authorName: current.getAttribute("creator"),
      postID: current.getAttribute("post_id"),
      avatarUrl: avatar,
      // TODO broken on rule34xxx? returns current time
      createDate: current.getAttribute("created_at"), // 2021-11-15 12:09
      createDateFormat: "yyyy-MM-dd HH:mm",
    );
  }

  // ----------------- Notes

  @override
  bool hasNotesSupport = true;

  @override
  String makeNotesURL(String postID) {
    return "${booru.baseURL}/index.php?page=dapi&s=note&q=index&post_id=$postID";
  }

  @override
  List parseNotesList(response) {
    var parsedResponse = XmlDocument.parse(response.body);
    return parsedResponse.findAllElements("note") as List;
  }

  @override
  NoteItem? parseNote(responseItem, int index) {
    var current = responseItem;
    return NoteItem(
      id: current.getAttribute("id"),
      postID: current.getAttribute("post_id"),
      content: current.getAttribute("body"),
      posX: int.tryParse(current.getAttribute("x") ?? '0') ?? 0,
      posY: int.tryParse(current.getAttribute("y") ?? '0') ?? 0,
      width: int.tryParse(current.getAttribute("width") ?? '0') ?? 0,
      height: int.tryParse(current.getAttribute("height") ?? '0') ?? 0,
    );
  }





  // ----------------- Helper functions

  bool isGelbooru() {
    return booru.baseURL!.contains("gelbooru.com");
  }

  bool isNotGelbooru() {
    return (booru.baseURL!.contains("rule34.xxx") || booru.baseURL!.contains("safebooru.org"));
  }
}

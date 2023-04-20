import { Injectable } from '@nestjs/common';
import {
  Enumeration,
  PostScope,
  TimelineType,
  BaseRoleType,
  MediumExtensionType,
} from '@/generated/types';

@Injectable()
export class EnumerationService {
  enumeration(): Enumeration {
    // nameを言語に応じて変えられるようにしたい
    return {
      postScopes: [
        { id: PostScope['PUBLIC'], name: '公開' },
        { id: PostScope['HOME'], name: 'ホーム' },
        { id: PostScope['FOLLOWERS_ONLY'], name: 'フォロワー限定' },
      ],
      timelineTypes: [
        { id: TimelineType['GLOBAL_TIMELINE'], name: 'グローバルタイムライン' },
        { id: TimelineType['HOME_TIMELINE'], name: 'ホームタイムライン' },
        { id: TimelineType['LOCAL_TIMELINE'], name: 'ローカルタイムライン' },
        { id: TimelineType['ANTENNA_TIMELINE'], name: 'アンテナタイムライン' },
      ],
      baseRoleTypes: [
        { id: BaseRoleType['ADMIN'], name: '管理者' },
        { id: BaseRoleType['MODERATOR'], name: 'モデレータ' },
        { id: BaseRoleType['USER'], name: 'ユーザ' },
        { id: BaseRoleType['BOT'], name: 'Bot' },
      ],
      mediaExtensionTypes: [
        { id: MediumExtensionType['AVI'], name: 'avi' },
        { id: MediumExtensionType['FLV'], name: 'flv' },
        { id: MediumExtensionType['GIF'], name: 'gif' },
        { id: MediumExtensionType['JPEG'], name: 'jpeg' },
        { id: MediumExtensionType['JPG'], name: 'jpg' },
        { id: MediumExtensionType['MKV'], name: 'mkv' },
        { id: MediumExtensionType['MOV'], name: 'mov' },
        { id: MediumExtensionType['MP3'], name: 'mp3' },
        { id: MediumExtensionType['MP4'], name: 'mp4' },
        { id: MediumExtensionType['OGG'], name: 'ogg' },
        { id: MediumExtensionType['PNG'], name: 'png' },
        { id: MediumExtensionType['SWF'], name: 'swf' },
        { id: MediumExtensionType['WEBM'], name: 'webm' },
        { id: MediumExtensionType['WEBP'], name: 'webp' },
        { id: MediumExtensionType['WMV'], name: 'wmv' },
        { id: MediumExtensionType['UNKNOWN'], name: 'unknown' },
      ],
    };
  }
}

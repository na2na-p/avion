import { MediumExtensionType } from '@/generated/types';
import { Choices } from '@/types/Choices';
import { IsExhaustive } from '../../utils/exhaustiveCheck';

export const mediaExtensionTypes = [
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
] satisfies Choices<MediumExtensionType>;

const _check: IsExhaustive<MediumExtensionType, typeof mediaExtensionTypes> =
  true;

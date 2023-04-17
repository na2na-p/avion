
/*
 * -------------------------------------------------------
 * THIS FILE WAS AUTOMATICALLY GENERATED (DO NOT MODIFY)
 * -------------------------------------------------------
 */

/* tslint:disable */
/* eslint-disable */

export enum PostScope {
    PUBLIC = "PUBLIC",
    HOME = "HOME",
    FOLLOWERS_ONLY = "FOLLOWERS_ONLY"
}

export enum TimelineType {
    HOME_TIMELINE = "HOME_TIMELINE",
    LOCAL_TIMELINE = "LOCAL_TIMELINE",
    GLOBAL_TIMELINE = "GLOBAL_TIMELINE",
    ANTENNA_TIMELINE = "ANTENNA_TIMELINE"
}

export enum BaseRoleType {
    ADMIN = "ADMIN",
    MODERATOR = "MODERATOR",
    USER = "USER",
    BOT = "BOT"
}

export enum MediumExtensionType {
    PNG = "PNG",
    JPEG = "JPEG",
    JPG = "JPG",
    GIF = "GIF",
    MP4 = "MP4",
    MP3 = "MP3",
    WEBM = "WEBM",
    WEBP = "WEBP",
    WMV = "WMV",
    AVI = "AVI",
    MOV = "MOV",
    MKV = "MKV",
    FLV = "FLV",
    SWF = "SWF",
    OGG = "OGG",
    UNKNOWN = "UNKNOWN"
}

export interface CreateDropInput {
    scope: PostScope;
    cw?: Nullable<string>;
    body?: Nullable<string>;
    mediums?: Nullable<string[]>;
    expiresAt?: Nullable<DateTime>;
}

export interface MediumsFilter {
    ids?: Nullable<string[]>;
    limit?: Nullable<number>;
    createdBy?: Nullable<string>;
    terminal?: Nullable<string>;
    name?: Nullable<string>;
    extension?: Nullable<MediumExtensionType>;
    isNsfw?: Nullable<boolean>;
    createdAtSince?: Nullable<DateTime>;
    createdAtUntil?: Nullable<DateTime>;
}

export interface CreateUserInput {
    userId: string;
    email?: Nullable<Email>;
    password: Password;
}

export interface UpdateUserInput {
    userId: string;
    userName?: Nullable<string>;
    icon: URI;
    email?: Nullable<Email>;
    introduction?: Nullable<string>;
}

export interface UpdatePasswordInput {
    id: string;
    password: Password;
}

export interface Node {
    id: string;
}

export interface IQuery {
    avion(): Nullable<string> | Promise<Nullable<string>>;
    allAntennas(): Nullable<Antenna>[] | Promise<Nullable<Antenna>[]>;
    drop(id: string): Drop | Promise<Drop>;
    timeline(type: TimelineType, limit?: Nullable<number>, after?: Nullable<string>, antennaId?: Nullable<string>): Drop[] | Promise<Drop[]>;
    emojis(): Emoji[] | Promise<Emoji[]>;
    emoji(id: string): Emoji | Promise<Emoji>;
    emojiCategories(): string[] | Promise<string[]>;
    enumeration(): Enumeration | Promise<Enumeration>;
    followees(): User[] | Promise<User[]>;
    followers(): User[] | Promise<User[]>;
    medium(id: string): Medium | Promise<Medium>;
    mediums(filter: MediumsFilter): Medium[] | Promise<Medium[]>;
    role(id: string): Role | Promise<Role>;
    allRoles(ids?: Nullable<string[]>): Nullable<Role[]> | Promise<Nullable<Role[]>>;
    terminal(id: string): Nullable<Terminal> | Promise<Nullable<Terminal>>;
    terminals(): Nullable<Terminal>[] | Promise<Nullable<Terminal>[]>;
    user(id: string): User | Promise<User>;
    allUsers(ids?: Nullable<string[]>, roleIds?: Nullable<string[]>, terminalId?: Nullable<string[]>, hasEmail?: Nullable<boolean>): User[] | Promise<User[]>;
}

export interface IMutation {
    avion(): Nullable<string> | Promise<Nullable<string>>;
    createDrop(input: createDropInput): Drop | Promise<Drop>;
    deleteDrop(id: string): boolean | Promise<boolean>;
    createEmoji(name: string, medium: string, categories: Nullable<string>[]): Emoji | Promise<Emoji>;
    updateEmoji(id: string, name: string, medium: string, categories: Nullable<string>[]): Emoji | Promise<Emoji>;
    deleteEmoji(id: string): boolean | Promise<boolean>;
    follow(followeeId: string): Follow | Promise<Follow>;
    unfollow(followeeId: string): Follow | Promise<Follow>;
    uploadMedium(name: string, mimeType: string, encoding: string, isNsfw: boolean): Medium | Promise<Medium>;
    createReaction(dropId: string, emojiId: string): Reaction | Promise<Reaction>;
    createRole(name: string, description?: Nullable<string>, baseType: BaseRoleType): Role | Promise<Role>;
    updateRole(id: string, name: string, description?: Nullable<string>, baseType: BaseRoleType): Role | Promise<Role>;
    deleteRole(id: string): Role | Promise<Role>;
    assignRole(roleId: string, userId: string): Role | Promise<Role>;
    unassignRole(roleId: string, userId: string): Role | Promise<Role>;
    assignMany(roleId: string, userIds?: Nullable<string[]>): Role | Promise<Role>;
    unassignMany(roleId: string, userIds?: Nullable<string[]>): Role | Promise<Role>;
    createUser(input: createUserInput): User | Promise<User>;
    updateUser(input: updateUserInput): User | Promise<User>;
    updatePassword(input: updatePasswordInput): User | Promise<User>;
    deleteUser(id: string): User | Promise<User>;
}

export interface Choice extends Node {
    id: string;
    name: string;
}

export interface Antenna extends Node {
    id: string;
    name: string;
    description?: Nullable<string>;
    conditions: string[];
    exclusions: string[];
    createdBy: User;
}

export interface Drop extends Node {
    id: string;
    user: User;
    scope?: Nullable<PostScope>;
    cw?: Nullable<string>;
    body?: Nullable<string>;
    medium: Nullable<Medium>[];
    reactions: Nullable<Reaction>[];
    createdAt: DateTime;
    expiresAt?: Nullable<DateTime>;
    deletedAt?: Nullable<DateTime>;
}

export interface Emoji extends Node {
    id: string;
    name: string;
    terminal: Terminal;
    medium: Medium;
    createdAt: DateTime;
    categories: Nullable<string>[];
}

export interface Enumeration {
    postScopes: Choice[];
    timelineTypes: Choice[];
    baseRoleTypes: Choice[];
    mediaExtensionTypes: Choice[];
}

export interface Follow extends Node {
    id: string;
    followee: User;
    follower: User;
    createdAt: DateTime;
}

export interface Medium extends Node {
    id: string;
    name: string;
    terminal?: Nullable<Terminal>;
    createdBy: User;
    url: URI;
    type: MediumExtensionType;
    isNsfw: boolean;
}

export interface Reaction extends Node {
    id: string;
    drop: Drop;
    reactedBy: User;
    emoji: Emoji;
}

export interface Role extends Node {
    id: string;
    name: string;
    description?: Nullable<string>;
    assignedUsers?: Nullable<User[]>;
    baseType: BaseRoleType;
}

export interface Terminal extends Node {
    id: string;
    name: string;
    firstSeen: DateTime;
    updatedAt: DateTime;
    userCount: number;
    dropCount: number;
    followees: Nullable<Follow>[];
    followers: Nullable<Follow>[];
    isRegistrationOpen: boolean;
}

export interface User extends Node {
    id: string;
    userId: string;
    terminal: Terminal;
    icon: Medium;
    email?: Nullable<Email>;
    introduction?: Nullable<string>;
    name?: Nullable<string>;
    assignedRoles: Role[];
    createdAt: DateTime;
    deletedAt?: Nullable<DateTime>;
}

export type DateTime = any;
export type URI = any;
export type Email = any;
export type Password = any;
type Nullable<T> = T | null;

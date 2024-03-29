module.exports = {
	rules: [
		'arguments-have-descriptions',
		'defined-types-are-used',
		'deprecations-have-a-reason',
		'descriptions-are-capitalized',
		'enum-values-all-caps',
		'enum-values-have-descriptions',
		'fields-are-camel-cased',
		'fields-have-descriptions',
		'input-object-values-are-camel-cased',
		'input-object-values-have-descriptions',
		'interface-fields-sorted-alphabetically',
		'relay-connection-types-spec',
		'relay-connection-arguments-spec',
		'types-are-capitalized',
		'types-have-descriptions',
	],
	schemaPaths: ['./dist/schema.graphql'],
	// NOTE: ホワイトリスト方式なのでignoreに追加しても無効にならない
	// ignore: [
	// 'enum-values-sorted-alphabetically',
	// 'type-fields-sorted-alphabetically',
	// 'input-object-fields-sorted-alphabetically'
	// ]
};

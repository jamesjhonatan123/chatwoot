<script>
import { mapGetters } from 'vuex';
import MentionBox from '../mentions/MentionBox.vue';

export default {
  components: { MentionBox },
  props: {
    searchKey: {
      type: String,
      default: '',
    },
  },
  emits: ['replace'],
  data() {
    return {
      allCannedMessages: [],
    };
  },
  computed: {
    ...mapGetters({
      cannedMessages: 'getCannedResponses',
    }),
    items() {
      const normalizedSearch = this.normalizeValue(this.searchKey);
      const cannedMessages = normalizedSearch
        ? [...this.allCannedMessages]
            .map(cannedMessage => ({
              cannedMessage,
              score: this.scoreCannedMessage(cannedMessage, normalizedSearch),
            }))
            .filter(({ score }) => score > 0)
            .sort((left, right) => right.score - left.score)
            .map(({ cannedMessage }) => cannedMessage)
        : this.allCannedMessages;

      return cannedMessages.map(cannedMessage => ({
        label: cannedMessage.short_code,
        key: cannedMessage.short_code,
        description: cannedMessage.content,
      }));
    },
  },
  async mounted() {
    await this.fetchCannedResponses();
  },
  methods: {
    normalizeValue(value = '') {
      return value
        .normalize('NFD')
        .replace(/[\u0300-\u036f]/g, '')
        .toLowerCase()
        .trim();
    },
    scoreCannedMessage(cannedMessage, normalizedSearch) {
      const normalizedShortCode = this.normalizeValue(cannedMessage.short_code);
      const normalizedContent = this.normalizeValue(cannedMessage.content);

      if (!normalizedShortCode && !normalizedContent) return 0;
      if (!normalizedSearch) return 1;

      const searchTerms = normalizedSearch.split(/\s+/).filter(Boolean);
      const shortCodeWords = normalizedShortCode
        .split(/[^a-z0-9]+/)
        .filter(Boolean);
      const contentWords = normalizedContent
        .split(/[^a-z0-9]+/)
        .filter(Boolean);

      let score = 0;

      if (normalizedShortCode === normalizedSearch) score += 1000;
      if (normalizedShortCode.startsWith(normalizedSearch)) score += 600;
      if (normalizedContent.startsWith(normalizedSearch)) score += 250;
      if (normalizedShortCode.includes(normalizedSearch)) score += 180;
      if (normalizedContent.includes(normalizedSearch)) score += 80;

      searchTerms.forEach(term => {
        if (shortCodeWords.some(word => word.startsWith(term))) score += 120;
        else if (normalizedShortCode.includes(term)) score += 50;

        if (contentWords.some(word => word.startsWith(term))) score += 40;
        else if (normalizedContent.includes(term)) score += 15;
      });

      return score;
    },
    async fetchCannedResponses() {
      await this.$store.dispatch('getCannedResponse', {
        searchKey: '',
      });
      this.allCannedMessages = [...this.cannedMessages];
    },
    handleMentionClick(item = {}) {
      this.$emit('replace', item.description);
    },
  },
};
</script>

<!-- eslint-disable-next-line vue/no-root-v-if -->
<template>
  <MentionBox
    v-if="items.length"
    :items="items"
    size="expanded"
    @mention-select="handleMentionClick"
  />
</template>

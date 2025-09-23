<script setup lang="ts">
import { getAddress, getCreateAddress, hexToBytes, type Hex } from "viem";
import {
  generatePrivateKey,
  privateKeyToAddress,
  publicKeyToAddress,
} from "viem/accounts";
import { computed, onMounted, ref } from "vue";
import loadPGlite from "./db";
import ChangeLogSynchronizer from "./sync";
import type { User } from "./types";
import { getRandomPubKey } from "./getRandomPubKey";

const nameFilter = ref("");
const name = ref("");
const pubKey = ref("");
const items = ref<User[]>([]);

const isLoading = ref(true);

function randomizePubKey() {
  pubKey.value = getRandomPubKey();
}

onMounted(async () => {
  const db = await loadPGlite();

  const synchronizer = new ChangeLogSynchronizer(db);
  synchronizer.start();

  await db.waitReady;

  const itemsQuery = await db.live.query<User>(
    `
    select '0x' || encode(pub_key, 'hex') as pub_key, name
    from users
    limit 10000
    `
  );

  items.value = itemsQuery.initialResults.rows;
  isLoading.value = false;

  itemsQuery.subscribe((result) => {
    items.value = result.rows;
  });
});

const addUser = async () => {
  const db = await loadPGlite();

  try {
    if (!name.value || !pubKey.value) {
      throw new Error("Name and public key are required");
    }

    let hexValue = pubKey.value;
    hexValue = hexValue.replace("\\x", "0x");
    if (!hexValue.startsWith("0x")) {
      hexValue = "0x" + hexValue;
    }

    await db.query("insert into users (name, pub_key) values ($1, $2)", [
      name.value,
      hexToBytes(hexValue as Hex),
    ]);
  } catch (error) {
    alert("Error adding user: " + error);
  }
};

const formattedItems = computed(() => {
  return items.value.map((item) => {
    return {
      ...item,
      pub_key: getAddress(item.pub_key as Hex),
    };
  });
});

const filteredItems = computed(() => {
  return formattedItems.value.filter((item) => {
    return item.name.toLowerCase().includes(nameFilter.value.toLowerCase());
  });
});
</script>

<template>
  <main class="max-w-2xl mx-auto p-4 flex flex-col gap-8">
    <form class="flex flex-col gap-4" @submit.prevent="addUser">
      <input
        type="text"
        class="w-full rounded-lg border p-2"
        v-model="name"
        placeholder="Name"
      />
      <div class="flex gap-2">
        <input
          type="text"
          class="w-full rounded-lg border p-2"
          v-model="pubKey"
          placeholder="Public Key"
        />
        <button
          @click="randomizePubKey"
          type="button"
          class="cursor-pointer rounded-lg p-2 bg-blue-600 text-white hover:bg-blue-700"
        >
          Random
        </button>
      </div>
      <button
        type="submit"
        class="cursor-pointer rounded-lg p-2 bg-blue-600 text-white hover:bg-blue-700"
      >
        Add User
      </button>
    </form>
    <hr class="border-zinc-300" />
    <div class="flex flex-col gap-4">
      <input
        type="text"
        class="w-full rounded-lg border p-2"
        v-model="nameFilter"
        placeholder="Search by name"
      />

      <div v-if="isLoading" class="p-4 border border-transparent">
        Loading...
      </div>
      <div v-else class="flex flex-col gap-2 border border-zinc-300 rounded-lg">
        <div v-if="filteredItems.length === 0" class="p-4">No users found</div>
        <div
          v-else
          class="even:bg-zinc-100 p-4 flex gap-1 justify-between"
          v-for="user in filteredItems"
          :key="user.pub_key"
        >
          <div>
            {{ user.name }}
          </div>
          <div class="text-ellipsis overflow-hidden font-mono">
            {{ user.pub_key }}
          </div>
        </div>
      </div>
    </div>
  </main>
</template>

<style scoped></style>

import { test, expect } from '@playwright/test';
import { LoginPage } from '../pages/LoginPage';
import { DashboardPage } from '../pages/DashboardPage';
import { CartPage } from '../pages/CartPage';
import { CheckoutPage } from '../pages/CheckoutPage';
import { validUser } from '../test-data/users';

test.describe('Client app - cart to checkout', () => {
  test('3 random products added to cart are present on checkout page', async ({ page }, testInfo) => {
    test.setTimeout(90_000);
    const loginPage = new LoginPage(page);
    const dashboardPage = new DashboardPage(page);
    const cartPage = new CartPage(page);
    const checkoutPage = new CheckoutPage(page);

    await loginPage.goto();
    await loginPage.login(validUser.email, validUser.password);

    // The cart is stored server-side per account, so start from an empty cart.
    await dashboardPage.goToCart();
    await cartPage.clearCart();
    await page.goBack();

    const addedProducts = await dashboardPage.addRandomProductsToCart(3);
    console.log('Added products:', addedProducts);

    await dashboardPage.goToCart();
    await expect(cartPage.itemNames).toHaveCount(addedProducts.length);
    expect((await cartPage.getItemNames()).sort()).toEqual([...addedProducts].sort());

    await cartPage.checkout();
    await expect(checkoutPage.itemTitles).toHaveCount(addedProducts.length);
    expect((await checkoutPage.getItemNames()).sort()).toEqual([...addedProducts].sort());

    const screenshotPath = 'screenshots/checkout-proof.png';
    await checkoutPage.takeScreenshot(screenshotPath);
    await testInfo.attach('checkout-proof', { path: screenshotPath, contentType: 'image/png' });
  });
});
